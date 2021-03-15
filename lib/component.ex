# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Component do
  @moduledoc """
  Component type definition and utilities.

  A component is a reusable data processing step that can be embedded inside of a workflow. It is
  defined as the combination of metadata and callbacks. The metadata contains information about
  the component used in workflow definitions and at runtime, while the callbacks define how the
  component processes data.

  A skitter component is defined as an elixir module which implements the `Skitter.Component`
  behaviour and defines a struct. The behaviour defines the `c:_sk_component_info/1` callback,
  which is used to store the component metadata. The struct is used to store the state of the
  component. It is not recommended to write a component by hand. Instead, use
  `Skitter.DSL.Component.defcomponent/3`.

  This module defines the component type, the callbacks of the component behaviour and some
  utilities to handle components.

  ## Examples

  Since components need to be defined in a module the example code shown in this module's
  documentation assumes the following module is defined:

  ```
  defmodule ComponentModule do
    @behaviour Skitter.Component
    @behaviour Skitter.Callback

    alias Skitter.Callback.{Info, Result}

    defstruct [:field]

    def _sk_component_info(:strategy), do: Strategy
    def _sk_component_info(:in_ports), do: [:input]
    def _sk_component_info(:out_ports), do: [:output]

    def _sk_callback_list, do: [:example]

    def _sk_callback_info(:example) do
      %Info{arity: 1, read?: true, write?: false, publish?: false}
    end

    def example(state, args) do
      %Result{result: args, state: state, publish: []}
    end
  end
  ```

  """
  @compile {:inline, create_empty_state: 1, call: 3, call: 4}

  alias Skitter.{Port, Callback, Strategy}

  # ---------------- #
  # Type & Behaviour #
  # ---------------- #

  @typedoc """
  A component is defined as a module which implements `Skitter.Component`.
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

  A component should also implement the `Skitter.Callback` behaviour.
  """
  @callback _sk_component_info(:in_ports) :: [Port.t(), ...]
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

  See `Skitter.Callback.call/4`.

  ## Examples

      iex> call(ComponentModule, :example, %ComponentModule{field: 30}, [42])
      %Skitter.Callback.Result{state: %ComponentModule{field: 30}, result: [42], publish: []}
  """
  @spec call(t(), atom(), Callback.state(), Callback.args()) :: Callback.result()
  def call(component, callback_name, state, arguments) do
    Callback.call(component, callback_name, state, arguments)
  end

  @doc """
  Call callback `callback_name` with and empty state and `arguments`.

  This function calls `Skitter.Callback.call/4` with the state created by `create_empty_state/1`.

  ## Examples

      iex> call(ComponentModule, :example, [42])
      %Skitter.Callback.Result{state: %ComponentModule{field: nil}, result: [42], publish: []}
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
  @spec in_ports(t()) :: [Port.t(), ...]
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
