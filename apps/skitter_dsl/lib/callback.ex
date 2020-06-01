# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.DSL.Callback do
  @moduledoc """
  Callback definition DSL. See `defcallback/4`.
  """
  alias Skitter.DSL.{DefinitionError, Utils}

  @publish_operator :~>
  @update_operator :<~

  @publish_var Utils.internal_var(:publish)
  @state_var Utils.internal_var(:state)

  @doc """
  DSL to create `t:Skitter.Callback.t/0`.

  This macro offers a DSL to create callbacks that can be used inside skitter
  components. This macro accepts the `fields` and `out_ports` of the component
  it will be embedded in as arguments. Any additional arguments that the
  callback will accept must be specified as a list of arguments which should be
  passed to `args`. Generally speaking, this macro should not be called
  directly.  `Skitter.DSL.Component.defcomponent/3` automatically calls this
  macro with appropriate values for `fields`, `out_ports`, and `args`.

  The `body` argument should contain the implementation of the callback. The
  body of the callback contains standard elixir code with a few additions and
  limitations:

  - the `~>` operator can be used to publish data to any out port provided in
  `out_ports` (an error is raised if the port is not present in `out_ports`).
  This is done with the following syntax: `value ~> port`. If multiple data is
  published on the same output port, the last write will be published.
  - the `<~` operator can be used to update the state passed to the callback.
  `field <~ value` will update `field` of the state. The provided field should
  be present in `fields` (an error is raised  if this is not the case).
  - Using any field name inside of `body` will read the current value of that
  field in the state passed to the callback activation. Thus, to avoid errors,
  variable names inside `body` should not have the same name as a field.

  As a result, this macro returns a callback with the correct capabilities and a
  function which return a `t:Skitter.Callback.Result.t/0`.

  ## Examples

  This callback calculates an average and publishes its current value on the
  `current` port. For educative reasons, it always returns 0.

      iex> c = defcallback([:total, :count], [:current], [value]) do
      ...>  count <~ count + 1
      ...>  total <~ total + value
      ...>  total / count ~> current
      ...>  0
      ...> end
      iex> c.publish_capability
      true
      iex> c.state_capability
      :readwrite
      iex> Callback.call(c, %{total: 5, count: 1}, [5])
      %Result{state: %{count: 2, total: 10}, publish: [current: 5.0], result: 0}
  """
  @doc section: :dsl
  defmacro defcallback(fields, out_ports, args, do: body) do
    try do
      body = transform_operators(fields, out_ports, body, __CALLER__)

      state = state_access(used?(body, :read_state), used?(body, :update_state))
      publish = used?(body, :publish)
      arity = length(args)

      {body, state_return, state_arg} = make_state_body_return(body, state)
      {body, publish_return} = make_publish_body_return(body, publish)

      func =
        quote do
          fn unquote(state_arg), unquote(args) ->
            import unquote(__MODULE__),
              only: [read_state: 1, update_state: 2, publish: 2, defcallback: 4]

            result = unquote(body)

            %unquote(Skitter.Callback.Result){
              state: unquote(state_return),
              publish: unquote(publish_return),
              result: result
            }
          end
        end

      quote do
        %unquote(Skitter.Callback){
          function: unquote(func),
          arity: unquote(arity),
          state_capability: unquote(state),
          publish_capability: unquote(publish)
        }
      end
    catch
      err -> handle_error(err)
    end
  end

  # Private Macros
  # --------------

  @doc false
  defmacro publish(port, value) do
    quote do
      unquote(@publish_var) =
        Keyword.put(unquote(@publish_var), unquote(port), unquote(value))
    end
  end

  @doc false
  defmacro update_state(field, value) do
    quote do
      unquote(@state_var) = %{
        unquote(@state_var)
        | unquote(field) => unquote(value)
      }
    end
  end

  @doc false
  defmacro read_state(field) do
    quote(do: unquote(@state_var)[unquote(field)])
  end

  # AST Transformations
  # -------------------

  # Makes the following changes to the body:
  #   - any variable with a name in `fields` is transformed into
  #   `read_state(field)`
  #   - Any use of <~ is transformed into `update_state(field, value)`, check
  #   if field exists.
  #   - Any use of the ~> operator is transformed into `publish(value, port)`,
  #   check if port exists.
  defp transform_operators(fields, out_ports, body, env) do
    Macro.prewalk(body, fn
      node = {name, _, atom} when is_atom(atom) ->
        if(name in fields, do: quote(do: read_state(unquote(name))), else: node)

      {@update_operator, _, [field, value]} ->
        field = Utils.name_to_atom(field, env)

        if field in fields do
          quote(do: update_state(unquote(field), unquote(value)))
        else
          throw {:error, :invalid_field, field, fields, env}
        end

      {@publish_operator, _, [value, port]} ->
        port = Utils.name_to_atom(port, env)

        if port in out_ports do
          quote(do: publish(unquote(port), unquote(value)))
        else
          throw {:error, :invalid_out_port, port, out_ports, env}
        end

      any ->
        any
    end)
  end

  # Check if `symbol` is used in `ast`
  defp used?(ast, symbol) do
    {_, n} =
      Macro.prewalk(ast, 0, fn
        ast = {^symbol, _env, _args}, acc -> {ast, acc + 1}
        ast, acc -> {ast, acc}
      end)

    n >= 1
  end

  # Check state access based on read / write
  defp state_access(_, true), do: :readwrite
  defp state_access(true, false), do: :read
  defp state_access(false, false), do: :none

  # Create body and return value and function argument for state
  defp make_state_body_return(body, :readwrite) do
    {Utils.make_mutable_in_block(body, @state_var), @state_var, @state_var}
  end

  defp make_state_body_return(body, :none) do
    {body, nil, Utils.internal_var(:_)}
  end

  defp make_state_body_return(body, :read) do
    {body, nil, @state_var}
  end

  # Create body and return value for publishing values
  defp make_publish_body_return(body, true) do
    body = Utils.make_mutable_in_block(body, @publish_var)

    body =
      quote do
        unquote(@publish_var) = []
        unquote(body)
      end

    {body, @publish_var}
  end

  defp make_publish_body_return(body, false), do: {body, nil}

  # Error Handling
  # --------------

  defp handle_error({:error, :invalid_syntax, statement, env}) do
    DefinitionError.inject("Invalid syntax: `#{statement}`", env)
  end

  defp handle_error({:error, :invalid_field, field, fields, env}) do
    DefinitionError.inject(
      "Invalid field: `#{field}` is not a part of `#{inspect(fields)}`",
      env
    )
  end

  defp handle_error({:error, :invalid_out_port, port, out_ports, env}) do
    DefinitionError.inject(
      "Invalid out port: `#{port}` is not a part of `#{inspect(out_ports)}`",
      env
    )
  end
end
