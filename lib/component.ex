# Copyright 2018 - 2021, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Component do
  @moduledoc """
  Component type definition and utilities.

  A component is a reusable data processing step that can be embedded inside of a workflow. It is
  defined as the combination of a set of callbacks, which implement the logic of the component,
  and some metadata, which define how the component is embedded inside a workflow and how it is
  distributed over the cluster at runtime.

  A skitter component is defined as an elixir module which implements the `Skitter.Component`
  behaviour. This behaviour defines various callbacks, which are used to track component metadata
  and callback information. At runtime, a component handles component-specific state. This state
  is represented as a struct which should be defined by the component module. Thus, a component
  module should:

  - Implement the `Skitter.Component` behaviour.
  - Define a struct.

  Instead of doing this manually, it is recommend to use `Skitter.DSL.Component.defcomponent/3` to
  define a component.

  This module defines the component type and behaviour along with some utilities to handle
  components.

  ## Callbacks

  A component defines various _callbacks_: functions which implement the processing logic of a
  component. These callbacks need to have the ability to modify state and publish data when they
  are called. Callbacks are implemented as elixir functions with a few properties:

  - Callbacks accept `t:state/0` as their first argument.
  - Callbacks return a `t:result/0` struct, which wraps the result of the callback call along with
  the updated state and published data.

  Besides this, callbacks track additional information about how it access state and which data it
  publishes. This information is stored inside the callbacks defined in this module.

  ## Examples

  Since components need to be defined in a module the example code shown in this module's
  documentation assumes the following module is defined:

  ```
  defmodule ComponentModule do
    @behaviour Skitter.Component
    alias Skitter.Component.Callback.{Info, Result}

    defstruct [:field]

    def _sk_component_info(:strategy), do: Strategy
    def _sk_component_info(:in_ports), do: [:input]
    def _sk_component_info(:out_ports), do: [:output]

    def _sk_callback_list, do: [example: 1]

    def _sk_callback_info(:example, 1) do
      %Info{read: [:field], write: [], publish: [:arg]}
    end

    def example(state, arg) do
      result = Map.get(state, :field)
      %Result{state: state, publish: [arg: arg], result: result}
    end
  end
  ```
  """

  alias Skitter.{Port, Strategy, DefinitionError, Component.Callback.Info}

  # ----- #
  # Types #
  # ----- #

  @typedoc """
  A component is defined as a module.

  This module should implement the `Skitter.Component` behaviour, and define a struct.
  """
  @type t :: module()

  @typedoc """
  Arguments passed to a callback when it is called.

  The arguments are wrapped in a list.
  """
  @type args :: [any()]

  @typedoc """
  State passed to the callback when it is called.

  The state is wrapped in the component's module struct.
  """
  @type state :: struct()

  @typedoc """
  Output published by a callback.

  Published data is returned as a list where the output for each out port is specified. When no
  data is published on a port, the port should be omitted from the published list. The data
  published by a callback for a port should always be wrapped in a list. Each element in this list
  will be sent to downstream component separately.
  """
  @type publish :: [{Port.t(), [any()]}]

  @typedoc """
  Values returned by a callback when it is called.

  The following information is stored:

  - `:result`: The actual result of the callback, i.e. the final value returned in its body.
  - `:state`: The (possibly modified) state after calling the callback.
  - `:publish`: The list of output published by the callback.
  """
  @type result :: %__MODULE__.Callback.Result{
          result: any(),
          state: state(),
          publish: publish()
        }

  @typedoc """
  Additional callback information. Can be retrieved with `info/2`.

  The following information is stored:

  - `:read`: The state fields read inside the callback.
  - `:write`: The state fields updated by the callback.
  - `:publish`: The ports this callback published to.
  """
  @type info :: %__MODULE__.Callback.Info{
          read: [atom()],
          write: [atom()],
          publish: [atom()]
        }

  # Struct Definitions
  # ------------------

  defmodule Callback do
    @moduledoc false

    defmodule Result do
      @moduledoc false
      defstruct [:state, :publish, :result]
    end

    defmodule Info do
      @moduledoc false
      defstruct read: [], write: [], publish: []
    end
  end

  # --------- #
  # Behaviour #
  # --------- #

  @doc """
  Returns the meta-information of the component.

  The following information is stored:

  - `:in_ports`: A list of port names which represents in ports through which the component
  receives incoming data.

  - `:out_ports`: A list of out ports names which represents the out ports the component can use
  to publish data.

  - `:strategy`: The `Skitter.Strategy` of the component. `nil` may be provided instead, in which
  case a strategy must be provided when the component is embedded in a workflow.
  """
  @callback _sk_component_info(:in_ports) :: [Port.t()]
  @callback _sk_component_info(:out_ports) :: [Port.t()]
  @callback _sk_component_info(:strategy) :: Strategy.t() | nil

  @doc """
  Return the names and arities of all the callbacks defined in this module.
  """
  @callback _sk_callback_list() :: [{atom(), arity()}]

  @doc """
  Return the callback information of callback `name`, `arity`.
  """
  @callback _sk_callback_info(name :: atom(), arity()) :: info()

  # --------- #
  # Utilities #
  # --------- #

  # Component
  # ---------

  @doc """
  Check if a given value refers to a component module.

  ## Examples

      iex> component?(5)
      false
      iex> component?(String)
      false
      iex> component?(ComponentModule)
      true
  """
  @spec component?(any()) :: boolean()
  def component?(atom) when is_atom(atom) do
    :erlang.function_exported(atom, :_sk_component_info, 1)
  end

  def component?(_), do: false

  @doc """
  Create an empty state struct for the given component.

  ## Examples

      iex> create_empty_state(ComponentModule)
      %ComponentModule{field: nil}
  """
  @spec create_empty_state(t()) :: state()
  def create_empty_state(component), do: component.__struct__()

  @doc """
  Obtain the strategy of `component`.

  ## Examples

      iex> strategy(ComponentModule)
      Strategy
  """
  @spec strategy(t()) :: Strategy.t() | nil
  def strategy(component), do: component._sk_component_info(:strategy)

  @doc """
  Obtain the arity of `component`.

  The arity is defined as the amount of in ports the component defines.

  ## Examples

      iex> arity(ComponentModule)
      1
  """
  @spec arity(t()) :: arity()
  def arity(component), do: component |> in_ports() |> length()

  @doc """
  Obtain the list of in ports of `component`.

  ## Examples

      iex> in_ports(ComponentModule)
      [:input]
  """
  @spec in_ports(t()) :: [Port.t()]
  def in_ports(component), do: component._sk_component_info(:in_ports)

  @doc """
  Obtain the list of out ports of `component`.

  ## Examples

      iex> out_ports(ComponentModule)
      [:output]
  """
  @spec out_ports(t()) :: [Port.t()]
  def out_ports(component), do: component._sk_component_info(:out_ports)

  @doc """
  Check if a component is a source.

  A component is a source if it does not have any in ports.

  ## Examples

      iex> source?(ComponentModule)
      false
  """
  @spec source?(t()) :: boolean()
  def source?(component), do: component |> in_ports() |> length() == 0

  @doc """
  Check if a component is a sink.

  A component is a sink if it does not have any out ports.

  ## Examples

      iex> sink?(ComponentModule)
      false
  """
  @spec sink?(t()) :: boolean()
  def sink?(component), do: component |> out_ports() |> length() == 0

  # Callbacks
  # ---------

  @doc """
  Obtain the list of all callbacks defined in `component`.

  ## Examples

      iex> callback_list(ComponentModule)
      [example: 1]

  """
  @spec callback_list(t()) :: [{atom(), arity()}]
  def callback_list(component), do: component._sk_callback_list()

  @doc """
  Obtain the callback information for callback `name`, `arity` in `component`.

  ## Examples

      iex> callback_info(ComponentModule, :example, 1)
      %Info{read: [:field], write: [], publish: [:arg]}

  """
  @spec callback_info(t(), atom(), arity()) :: info()
  def callback_info(component, name, arity), do: component._sk_callback_info(name, arity)

  @doc """
  Call callback `callback_name` with `state` and `arguments`.

  ## Examples

      iex> call(ComponentModule, :example, %ComponentModule{field: :val}, [42])
      %Skitter.Component.Callback.Result{state: %ComponentModule{field: :val}, result: :val, publish: [arg: 42]}
  """
  @spec call(t(), atom(), state(), args()) :: result()
  def call(component, name, state, args), do: apply(component, name, [state | args])

  @doc """
  Call callback `callback_name` with and empty state and `arguments`.

  This function calls `Skitter.Component.call/4` with the state created by
  `create_empty_state/1`.

  ## Examples

      iex> call(ComponentModule, :example, [42])
      %Skitter.Component.Callback.Result{state: %ComponentModule{field: nil}, result: nil, publish: [arg: 42]}
  """
  @spec call(t(), atom(), args()) :: result()
  def call(component, callback_name, args) do
    call(component, callback_name, create_empty_state(component), args)
  end

  @doc """
  Verify if the `property` of the provided `info` satisfies `property`

  This function will lookup the property of a callback in the provided `t:info/0` struct and
  compare it to an expected value.

  - If the property is not present in `t:info/0`, `{:error, :invalid}` is returned.

  - If the property has the same value as `expected`, `:ok` is returned.

  - If the values do not match, the `{:error, actual value}` is returned.

  As a special case, the properties, `read?`, `write?` and `publish?` may be passed along with a
  boolean value. When this value is `false`, `verify_info` ensures the corresponding property
  (`read`, `write`, or `publish`) is equal to the empty list. When `true` is passed, any value for
  `read`, `write` or `publish` is accepted. This is done to enable `verify_info/3` to ensure a
  callback does not update its state or publish data when this is not allowed.

  ## Examples

      iex> verify_info(%Info{read: [:field]}, :read, [:field])
      :ok

      iex> verify_info(%Info{read: [:field]}, :read, [])
      {:error, [:field]}

      iex> verify_info(%Info{read: [:field]}, :red, [:field])
      {:error, :invalid}

      iex> verify_info(%Info{read: [:field]}, :read?, true)
      :ok

      iex> verify_info(%Info{read: [:field]}, :read?, false)
      {:error, [:field]}

      iex> verify_info(%Info{write: []}, :write?, true)
      :ok

      iex> verify_info(%Info{write: []}, :write?, false)
      :ok

      iex> verify_info(%Info{publish: []}, :publish?, false)
      :ok

  """
  @spec verify_info(info(), atom(), any()) :: :ok | {:error, :invalid | any()}

  def verify_info(_, property, true) when property in [:read?, :write?, :publish?], do: :ok

  def verify_info(info = %Info{}, :read?, false), do: verify_info(info, :read, [])
  def verify_info(info = %Info{}, :write?, false), do: verify_info(info, :write, [])
  def verify_info(info = %Info{}, :publish?, false), do: verify_info(info, :publish, [])

  def verify_info(info = %Info{}, property, expected) do
    case Map.get(info, property) do
      nil -> {:error, :invalid}
      ^expected -> :ok
      value -> {:error, value}
    end
  end

  @doc """
  Verify if the `property` of a callback satisfies `property`

  Works like `verify_info/3`, but raises a `Skitter.DefinitionError` if the properties do not
  match. `:ok` is returned if the properties match.

  ## Examples

      iex> verify_info!(%Info{write: []}, :write, [], "example")
      :ok

      iex> verify_info!(%Info{write: []}, :write, [:field], "example")
      ** (Skitter.DefinitionError) Incorrect write for callback example, expected [:field], got []

      iex> verify_info!(%Info{write: []}, :wrte, [], "example")
      ** (Skitter.DefinitionError) `wrte` is not a valid property name

      iex> verify_info!(%Info{read: []}, :read?, true, "example")
      :ok

      iex> verify_info!(%Info{read: [:field]}, :read?, false, "example")
      ** (Skitter.DefinitionError) Incorrect read for callback example, expected [], got [:field]

      iex> verify_info!(%Info{read: []}, :write?, true, "example")
      :ok

      iex> verify_info!(%Info{read: []}, :write?, false, "example")
      :ok

      iex> verify_info!(%Info{publish: []}, :publish?, false, "example")
      :ok

  """
  @spec verify_info!(info(), atom(), any(), String.t()) :: :ok | no_return()

  def verify_info!(_, property, true, _) when property in [:read?, :write?, :publish?], do: :ok

  def verify_info!(info = %Info{}, :read?, false, n), do: verify_info!(info, :read, [], n)
  def verify_info!(info = %Info{}, :write?, false, n), do: verify_info!(info, :write, [], n)
  def verify_info!(info = %Info{}, :publish?, false, n), do: verify_info!(info, :publish, [], n)

  def verify_info!(info = %Info{}, property, value, name) do
    case verify_info(info, property, value) do
      :ok ->
        :ok

      {:error, :invalid} ->
        raise DefinitionError, "`#{property}` is not a valid property name"

      {:error, actual} ->
        value = inspect(value)
        actual = inspect(actual)

        raise DefinitionError,
              "Incorrect #{property} for callback #{name}, expected #{value}, got #{actual}"
    end
  end

  @doc """
  Verify the properties of a callback using `verify_info!/4`.

  This function accepts a keyword list of `{property, expected_value}` pairs and compares each of
  them with `verify_info!/4`.

  ## Examples

      iex> verify_info!(%Info{read: [], write: [:field]}, "example", read?: true, write?: true)
      :ok

      iex> verify_info!(%Info{read: [], write: [:field]}, "example")
      :ok

      iex> verify_info!(%Info{write: [:field]}, "example", publish?: true, wrt: [])
      ** (Skitter.DefinitionError) `wrt` is not a valid property name

      iex> verify_info!(%Info{publish: [:port]}, "example", publish?: false)
      ** (Skitter.DefinitionError) Incorrect publish for callback example, expected [], got [:port]
  """
  @spec verify_info!(info(), String.t(), [{atom(), any()}]) :: :ok | no_return()
  def verify_info!(info = %Info{}, name, properties \\ []) do
    Enum.each(properties, fn {property, value} -> verify_info!(info, property, value, name) end)
  end

  @doc """
  Verify if the `property` of the provided callback satisfies `property`.

  This function calls `verify_info/3` on the `callback_info/3` of the provided callback. If the
  callback does not exist, `{error, :missing}` is returned.

  ## Examples

      iex> verify(ComponentModule, :example, 1, :read, [:field])
      :ok

      iex> verify(ComponentModule, :exampl, 1, :read, [:field])
      {:error, :missing}

      iex> verify(ComponentModule, :example, 1, :read, [])
      {:error, [:field]}

      iex> verify(ComponentModule, :example, 1, :red, [:field])
      {:error, :invalid}

      iex> verify(ComponentModule, :example, 1, :read?, true)
      :ok
  """
  @spec verify(t(), atom(), arity(), atom(), any()) :: :ok | {:error, :invalid | :missing | any()}
  def verify(component, name, arity, property, value) do
    if {name, arity} in callback_list(component) do
      callback_info(component, name, arity) |> verify_info(property, value)
    else
      {:error, :missing}
    end
  end

  @doc """
  Verify if the `property` of the provided callback satisfies `property`.

  This function calls `verify_info!/4` on the `callback_info/3` of the provided callback.

  ## Examples

      iex> verify!(ComponentModule, :example, 1, :read, [:field])
      :ok

      iex> verify!(ComponentModule, :exampl, 1, :read, [:field])
      ** (Skitter.DefinitionError) Missing required callback exampl with arity 1

      iex> verify!(ComponentModule, :example, 1, :read, [])
      ** (Skitter.DefinitionError) Incorrect read for callback example, expected [], got [:field]

      iex> verify!(ComponentModule, :example, 1, :red, [:field])
      ** (Skitter.DefinitionError) `red` is not a valid property name

      iex> verify!(ComponentModule, :example, 1, :read?, true)
      :ok
  """
  @spec verify!(t(), atom(), arity(), atom(), any()) :: :ok | no_return()
  def verify!(component, name, arity, property, value) do
    if {name, arity} in callback_list(component) do
      callback_info(component, name, arity) |> verify_info!(property, value, Atom.to_string(name))
    else
      raise Skitter.DefinitionError, "Missing required callback #{name} with arity #{arity}"
    end
  end

  @doc """
  Verify the properties of a callback using `verify_info!/3`.

  This function calls `verify_info!/3` on the `callback_info/3` of the provided callback.

  ## Examples

      iex> verify!(ComponentModule, :example, 1, read?: true, write?: true)
      :ok

      iex> verify!(ComponentModule, :example, 1)
      :ok

      iex> verify!(ComponentModule, :exampl, 1)
      ** (Skitter.DefinitionError) Missing required callback exampl with arity 1

      iex> verify!(ComponentModule, :example, 1, publish?: true, wrt: [])
      ** (Skitter.DefinitionError) `wrt` is not a valid property name

      iex> verify!(ComponentModule, :example, 1, publish?: false)
      ** (Skitter.DefinitionError) Incorrect publish for callback example, expected [], got [:arg]
  """
  @spec verify!(t(), atom(), arity(), [{atom(), any()}]) :: :ok | no_return()
  def verify!(component, name, arity, properties \\ []) do
    if {name, arity} in callback_list(component) do
      callback_info(component, name, arity) |> verify_info!(Atom.to_string(name), properties)
    else
      raise Skitter.DefinitionError, "Missing required callback #{name} with arity #{arity}"
    end
  end
end
