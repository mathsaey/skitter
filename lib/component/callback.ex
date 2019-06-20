# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Component.Callback do
  @moduledoc """
  Representation of a component callback.

  A callback is a piece of code which implements some functionality of a
  `Skitter.Component`. Internally, a callback is defined as an anonymous
  function and some metadata.

  This module also contains `defcallback/4`, a DSL which can be used to define
  callbacks.
  """
  alias Skitter.{Component, Port, DSL, DefinitionError}

  # Types
  # -----

  defstruct [:function, :state_capability, :publish_capability]

  defmodule Result do
    @moduledoc """
    Struct returned by a successful component callback.

    A callback returns the following:
    - The updated state, or `nil` if the state has not been changed.
    - The published data or `nil` if no data has been published.
    - The result of the callback
    """
    alias Skitter.Component.Callback

    defstruct [:state, :publish, :result]

    @type t :: %__MODULE__{
            state: Callback.state(),
            publish: Callback.publish(),
            result: any()
          }
  end

  @typedoc """
  Callback representation.

  A callback is defined as a function with type `t:signature`, which implements
  the functionality of the callback and a set of metadata which define the
  capabilities of the callback.

  The following capabilities are defined:

  - `state_capability`: Defines if the callback is allowed to read or write the
  state of the component instance.
  - `publish_capability`: Defines if the callback may publish data
  """
  @type t :: %__MODULE__{
          function: signature(),
          state_capability: state_capability(),
          publish_capability: publish_capability()
        }

  @typedoc """
  Structure of published data.

  When a callback publishes data it returns the published data as a keyword
  list. The keys in this list represent the names of output ports; the values
  of the keys represent the data to be publish on an output port.
  """
  @type publish :: [{Port.t(), any()}]

  @typedoc """
  Structure of the component state.

  When a callback is executed, it may access to the state of a component
  instance (see `t:state_capability/0`). At the end of the invocation of the
  callback, the (possibly updated) state is returned as part of the result of
  the callback.

  This state is represented as a map, where each key corresponds to a
  `t:Component.field/0`. The value for each key corresponds to the current
  value of the field.
  """
  @type state :: %{optional(Component.field()) => any}

  @typedoc """
  Result returned by the invocation of a callback.

  A successful callback returns a `t:Result.t/0` struct, which contains the
  updated state, published data and result value of the callback.
  When not successful, the callback returns an `{:error, reason}` tuple.
  """
  @type result :: Result.t() | {:error, any()}

  @typedoc """
  Function signature of a callback.

  A skitter callback accepts the state of an instance, along with an arbitrary
  amount of arguments wrapped in a list. The return value is defined by
  `t:result/0`.
  """
  @type signature :: (state(), [any()] -> result())

  @typedoc """
  Defines how the callback may access the state.
  """
  @type state_capability :: :none | :read | :readwrite

  @typedoc """
  Defines if the callback can publish data.
  """
  @type publish_capability :: boolean()

  # Utilities
  # ---------

  @doc """
  Check if the callback adheres to its capabilities.

  Concretely, this means that the callback does not access the state or publish
  data when it is not allowed to.

  Note that a callback may have a permission without using it. E.g. a callback
  may have a `:readwrite` state capability and only read the state or not
  access it at all.

  ## Examples

      iex> check_permissions(
      ...>  %Callback{state_capability: :read, publish_capability: true},
      ...>  :readwrite,
      ...>  true
      ...> )
      true
      iex> check_permissions(
      ...>  %Callback{state_capability: :read, publish_capability: true},
      ...>  :none,
      ...>  true
      ...> )
      false
      iex> check_permissions(
      ...>  %Callback{state_capability: :none, publish_capability: true},
      ...>  :none,
      ...>  false
      ...> )
      false
      iex> check_permissions(
      ...>  %Callback{state_capability: :none, publish_capability: false},
      ...>  :none,
      ...>  false
      ...> )
      true
  """
  @spec check_permissions(t(), state_capability(), boolean()) :: boolean()
  def check_permissions(
        cb = %__MODULE__{},
        state_capability,
        publish_capability
      ) do
    state_order(cb.state_capability) <= state_order(state_capability) and
      (cb.publish_capability == publish_capability or publish_capability)
  end

  defp state_order(:none), do: 0
  defp state_order(:read), do: 1
  defp state_order(:readwrite), do: 2

  @doc """
  Call the callback.

  ## Examples

      iex> cb = defcallback([:field], [:out], [arg1, arg2]) do
      ...>  field <~ field + arg1
      ...>  arg2 ~> out
      ...>  field
      ...> end
      iex> call(cb, %{field: 1}, [2, 3])
      %Result{state: %{field: 3}, publish: [out: 3], result: 3}
  """
  @spec call(t(), state(), [any()]) :: result()
  def call(%__MODULE__{function: f}, state, args), do: f.(state, args)

  # ------ #
  # Macros #
  # ------ #

  @publish_operator :~>
  @update_operator :<~

  @publish_var DSL.create_internal_var(:publish)
  @state_var DSL.create_internal_var(:state)

  @doc """
  DSL to create skitter callbacks.

  This macro offers a small DSL to create callbacks that can be used inside
  skitter components. This macro accepts the `fields` and `out_ports` of the
  component it will be embedded in as arguments. Any additional arguments that
  the callback will accept must be specified as a list of arguments which
  should be passed to `args`.

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
  function which will automatically return a `t:Result.t()` struct.

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
      iex> call(c, %{total: 5, count: 1}, [5])
      %Result{state: %{count: 2, total: 10}, publish: [current: 5.0], result: 0}
  """
  defmacro defcallback(fields, out_ports, args, do: body) do
    try do
      body = transform_operators(fields, out_ports, body, __CALLER__)

      state = state_access(used?(body, :read_state), used?(body, :update_state))
      publish = used?(body, :publish)

      {body, state_return, state_arg} = make_state_body_return(body, state)
      {body, publish_return} = make_publish_body_return(body, publish)

      func =
        quote do
          fn unquote(state_arg), unquote(args) ->
            import unquote(__MODULE__),
              only: [read_state: 1, update_state: 2, publish: 2]

            result = unquote(body)

            %unquote(__MODULE__.Result){
              state: unquote(state_return),
              publish: unquote(publish_return),
              result: result
            }
          end
        end

      quote do
        %unquote(__MODULE__){
          function: unquote(func),
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
        field = DSL.name_to_atom(field, env)

        if field in fields do
          quote(do: update_state(unquote(field), unquote(value)))
        else
          throw {:error, :invalid_field, field, fields, env}
        end

      {@publish_operator, _, [value, port]} ->
        port = DSL.name_to_atom(port, env)

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
    {DSL.make_mutable_in_block(body, @state_var), @state_var, @state_var}
  end

  defp make_state_body_return(body, :none) do
    {body, nil, DSL.create_internal_var(:_)}
  end

  defp make_state_body_return(body, :read) do
    {body, nil, @state_var}
  end

  # Create body and return value for publishing values
  defp make_publish_body_return(body, true) do
    body = DSL.make_mutable_in_block(body, @publish_var)

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
      "Invalid field: `#{field}` is not a part of `#{inspect fields}`", env
    )
  end

  defp handle_error({:error, :invalid_out_port, port, out_ports, env}) do
    DefinitionError.inject(
      "Invalid out port: `#{port}` is not a part of `#{inspect out_ports}`", env
    )
  end
end
