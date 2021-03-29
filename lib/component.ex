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

  A skitter component is defined as an elixir module which implements the `Skitter.Component` and
  `Skitter.Component.Callback` behaviours. The first behaviour defines the
  `c:_sk_component_info/1` callback, which is used to store the component metadata. The other
  behaviour is used to store the callbacks of the component. At runtime, a component handles
  component-specific state. This state is represented by a struct. In short, each component module
  should:

  - Implement the `Skitter.Component` behaviour.
  - Implement the `Skitter.Component.Callback` behaviour.
  - Define a struct.

  Instead of doing this manually, it is recommend to use `Skitter.DSL.Component.defcomponent/3`,
  which handles most of these steps automatically.

  This module defines the component type and behaviour along with some utilities to handle
  components.

  ## Examples

  Since components need to be defined in a module the example code shown in this module's
  documentation assumes the following module is defined:

  ```
  defmodule ComponentModule do
    @behaviour Skitter.Component
    @behaviour Skitter.Component.Callback

    alias Skitter.Component.Callback.{Info, Result}

    defstruct [:field]

    def _sk_component_info(:strategy), do: Strategy
    def _sk_component_info(:in_ports), do: [:input]
    def _sk_component_info(:out_ports), do: [:output]

    def _sk_callback_list, do: [example: 1]

    def _sk_callback_info(:example, 1) do
      %Info{read: [], write: [], publish: []}
    end

    def example(state, arg) do
      %Result{result: arg, state: state, publish: []}
    end
  end
  ```

  """
  @compile {:inline, create_empty_state: 1, call: 3, call: 4}

  alias Skitter.{Port, Strategy}
  alias Skitter.Component.Callback

  # ---------------- #
  # Type & Behaviour #
  # ---------------- #

  @typedoc """
  A component is defined as a module.

  This module should implement the `Skitter.Component` behaviour, implement the
  `Skitter.Component.Callback` behaviour and define a struct.
  """
  @type t :: module()

  @doc """
  Returns the meta-information of the component.

  The following information is stored:

  - `:in_ports`: A list of port names which represents in ports through which the component
  receives incoming data.

  - `:out_ports`: A list of out ports names which represents the out ports the component can use
  to publish data.

  - `:strategy`: The `Skitter.Strategy` of the component.
  """
  @callback _sk_component_info(:in_ports) :: [Port.t()]
  @callback _sk_component_info(:out_ports) :: [Port.t()]
  @callback _sk_component_info(:strategy) :: Strategy.t()

  # --------- #
  # Utilities #
  # --------- #

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
  @spec create_empty_state(t()) :: Callback.state()
  def create_empty_state(component), do: component.__struct__()

  @doc """
  Call callback `callback_name` with `state` and `arguments`.

  See `Skitter.Component.Callback.call/4`.

  ## Examples

      iex> call(ComponentModule, :example, %ComponentModule{field: 30}, [42])
      %Skitter.Component.Callback.Result{state: %ComponentModule{field: 30}, result: 42, publish: []}
  """
  @spec call(t(), atom(), Callback.state(), Callback.args()) :: Callback.result()
  def call(component, callback_name, state, arguments) do
    Callback.call(component, callback_name, state, arguments)
  end

  @doc """
  Call callback `callback_name` with and empty state and `arguments`.

  This function calls `Skitter.Component.Callback.call/4` with the state created by
  `create_empty_state/1`.

  ## Examples

      iex> call(ComponentModule, :example, [42])
      %Skitter.Component.Callback.Result{state: %ComponentModule{field: nil}, result: 42, publish: []}
  """
  @spec call(t(), atom(), Callback.args()) :: Callback.result()
  def call(component, callback_name, arguments) do
    Callback.call(component, callback_name, create_empty_state(component), arguments)
  end

  @doc """
  Obtain the strategy of `component`.

  ## Examples

      iex> strategy(ComponentModule)
      Strategy
  """
  @spec strategy(t()) :: Strategy.t()
  def strategy(component), do: component._sk_component_info(:strategy)

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
end
