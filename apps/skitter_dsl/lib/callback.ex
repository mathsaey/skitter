# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.DSL.Callback do
  @moduledoc """
  Callback definition DSL.

  This module offers a DSL to create a `Skitter.Callback`. A callback can be defined in two ways:
  first, it can be directly created through the `callback/3` macro defined in this module. This
  macro expects a list of fields, a list of out ports and a body as its arguments. In most cases,
  this macro should not be called explicitly. Instead, a callback can be defined inside
  `Skitter.DSL.Component.component/2` or `Skitter.DSL.Strategy.strategy/2`. These macros
  internally use `callback/3`, and ensure the correct values are provided for `fields` and
  `out_ports`.

  ## Callback body

  Inside the body of a callback, standard elixir syntax can be used; however, a few caveats apply:

  - the `~>` operator can be used to publish data to any out port provided in `out_ports` (an
  error is raised if the port is not present in `out_ports`).  This is done with the following
  syntax: `value ~> port`. If data is published on the same out port multiple times, the last data
  written will be published.
  - the `<~` operator can be used to update the state passed to the callback.  `field <~ value`
  will update `field` of the state. The provided field should be present in `fields` (an error is
  raised  if this is not the case).
  - Using any field name inside of `body` will read the current value of that field in the state
  passed to the callback activation. Thus, to avoid errors, variable names inside `body` should
  not have the same name as a field.

  ## Implicit callback definitions

  Inside `Skitter.DSL.Component.component/2` and `Skitter.DSL.Strategy.strategy/2`, a callback can
  be created using a `def`-like syntax:

  ```
  name arg1, arg2 do
    <body>
  end
  ```

  As with `def`, multiple clauses of the same function may be defined:

  ```
  name :foo, arg2 do
    :bar
  end
  name arg1, arg2 do
    <body>
  end
  ```

  The different clauses will be gathered and passed to `callback/3`. Note that all the clauses of
  a callback must have the same arity.
  """
  alias Skitter.DSL.{AST, DefinitionError, Mutable}

  # -------------------- #
  # Function-like Syntax #
  # -------------------- #

  @doc false
  # Internal function to extract function-like callbacks from an AST.
  #
  # This function accepts a component or strategy body, extracts function-like callbacks from this
  # body, and transforms them into calls to `callback/3`. A map is returned where the name of
  # the callback is the key while the actual callback is the value.
  #
  # `fields` and `out_ports` are passed to the `callback/3` calls, unless
  # `name => {fields, out_ports}` is present in `overrides`, in which case the `fields` and
  # `out_ports` present in that tuple get passed.
  # `imports` is added to the body passed to `callback`.
  def extract_callbacks(statements, imports, fields, out_ports, overrides \\ %{}) do
    callbacks =
      statements
      |> Enum.reject(&is_nil(&1))
      |> Enum.map(&read_callback(&1))
      |> Enum.reduce(%{}, &merge_callback(&1, &2))
      |> Enum.map(&add_imports_fields_ports(&1, imports, fields, out_ports, overrides))
      |> Enum.map(&build_callback(&1))

    {:%{}, [], callbacks}
  end

  # Read a `name args do ... end` ast node and extract the name, args and body.
  defp read_callback({name, _, args}) do
    {args, [[do: body]]} = Enum.split(args, -1)
    {name, args, body}
  end

  # Group callbacks by their names
  defp merge_callback({name, args, body}, map) do
    Map.update(map, name, [{args, body}], &(&1 ++ [{args, body}]))
  end

  # Add imports, fields, out, to each tuple, keeping track of possible overrides
  defp add_imports_fields_ports({name, bodies}, imports, fields, out, overrides) do
    {fields, out} = overrides[name] || {fields, out}
    {name, bodies, imports, fields, out}
  end

  # Build a callback from a name and a list of {args, body} tuples
  # Ensure imports, fields and out ports are passed along
  defp build_callback({name, bodies, imports, fields, out}) do
    clauses =
      Enum.flat_map(bodies, fn {args, body} ->
        quote do
          unquote_splicing(args) ->
            unquote(imports)
            unquote(body)
        end
      end)

    callback =
      quote do
        import unquote(Skitter.DSL.Callback), only: [callback: 3]

        callback(unquote(fields), unquote(out)) do
          unquote(clauses)
        end
      end

    {name, callback}
  end

  # -------- #
  # callback #
  # -------- #

  @publish_operator :~>
  @update_operator :<~

  @publish_var AST.internal_var(:publish)
  @state_var AST.internal_var(:state)

  @doc """
  DSL to create `t:Skitter.Callback.t/0`.

  This macro offers a DSL to create callbacks that can be used inside skitter components and
  strategies. This macro accepts `fields`, `out_ports` and a body as its arguments. As stated in
  the module documentation, this macro should not be called directly if it can be avoided.
  Instead, rely on the `Skitter.DSL.Component.component/2` and `Skitter.DSL.Strategy.strategy/2`
  macros to call this macro.

  The `body` argument should contain the actual implementation of the callback. This body consists
  of `fn`-like clauses (`argument -> body`). The body of these clauses contain standard elixir
  code with a few additions and limitations described in the module documentation.

  ## Examples

  This callback calculates an average and publishes its current value on the `current` port. When
  it is called with the `:latest` argument, it returns the current average.

      iex> c = callback([:total, :count], [:current]) do
      ...>  :latest ->
      ...>    total / count
      ...>  value ->
      ...>    count <~ count + 1
      ...>    total <~ total + value
      ...>    total / count ~> current
      ...>    :ok
      ...> end
      iex> c.publish?
      true
      iex> c.read?
      true
      iex> c.write?
      true
      iex> Callback.call(c, %{total: 5, count: 1}, [5])
      %Result{state: %{count: 2, total: 10}, publish: [current: 5.0], result: :ok}
      iex> Callback.call(c, %{total: 10, count: 2}, [:latest])
      %Result{state: %{count: 2, total: 10}, publish: [], result: 5.0}
  """
  @doc section: :dsl
  defmacro callback(fields, out_ports, do: body) do
    try do
      body = transform_operators(fields, out_ports, body, __CALLER__)
      read? = used?(body, :read_state)
      write? = used?(body, :update_state)
      publish? = used?(body, :publish)

      clauses = Enum.map(body, fn {:->, _, [args, body]} -> {args, body} end)
      arity = read_arity(clauses, __CALLER__)

      bodies =
        Enum.flat_map(clauses, fn {args, body} ->
          {body, state_return, state_arg} = make_state_body_return(body, read?, write?)
          {body, publish_return} = make_publish_body_return(body, publish?)

          quote do
            unquote(state_arg), unquote(args) ->
              import unquote(__MODULE__),
                only: [read_state: 1, update_state: 2, publish: 2, callback: 3]

              result = unquote(body)

              %unquote(Skitter.Callback.Result){
                state: unquote(state_return),
                publish: unquote(publish_return),
                result: result
              }
          end
        end)

      func = {:fn, [], bodies}

      quote do
        %unquote(Skitter.Callback){
          function: unquote(func),
          arity: unquote(arity),
          read?: unquote(read?),
          write?: unquote(write?),
          publish?: unquote(publish?)
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
      unquote(@publish_var) = Keyword.put(unquote(@publish_var), unquote(port), unquote(value))
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
        field = AST.name_to_atom(field, env)

        if field in fields do
          quote(do: update_state(unquote(field), unquote(value)))
        else
          throw {:error, :invalid_field, field, fields, env}
        end

      {@publish_operator, _, [value, port]} ->
        port = AST.name_to_atom(port, env)

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

  # Check the arity of the various clauses, make sure they are all the same and return it
  defp read_arity(clauses, env) do
    arities = clauses |> Enum.map(&elem(&1, 0)) |> Enum.map(&length/1)
    arity = hd(arities)

    if Enum.all?(arities, &(&1 == arity)) do
      arity
    else
      throw {:error, :arity_mismatch, env}
    end
  end

  # Create body and return value and function argument for state
  defp make_state_body_return(body, _, true) do
    {Mutable.make_mutable_in_block(body, @state_var), @state_var, @state_var}
  end

  defp make_state_body_return(body, true, false), do: {body, nil, @state_var}
  defp make_state_body_return(body, false, false), do: {body, nil, AST.internal_var(:_)}

  # Create body and return value for publishing values
  defp make_publish_body_return(body, true) do
    body = Mutable.make_mutable_in_block(body, @publish_var)

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

  defp handle_error({:error, :arity_mismatch, env}) do
    DefinitionError.inject("Callback clauses must have the same arity", env)
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
