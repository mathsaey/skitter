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
  behaviour. This behaviour defines various elixir callbacks which are used to track component
  information such as the defined callbacks. Instead of implementing a component as an elixir
  module, it is recommend to use `Skitter.DSL.Component.defcomponent/3`, which automatically
  generates the appropriate callbacks.

  This module defines the component type and behaviour along with utilities to handle components.

  ## Callbacks

  A component defines various _callbacks_: functions which implement the data processing logic of
  a component. These callbacks need to have the ability to modify state and emit data when they
  are called. Callbacks are implemented as elixir functions with a few properties:

  - Callbacks accept `t:state/0` and `t:config/0` as their first and second arguments.
  - Callbacks return a `t:result/0` struct, which wraps the result of the callback call along with
  the updated state and emitted data.

  Besides this, callbacks track additional information about whether they access or modify state
  and which data they emit. This information is stored inside the behaviour callbacks defined in
  this module.

  ## Examples

  Since components need to be defined in a module the example code shown in this module's
  documentation assumes the following module is defined:

  ```
  defmodule ComponentModule do
    @behaviour Skitter.Component
    alias Skitter.Component.Callback.{Info, Result}

    def _sk_component_info(:strategy), do: Strategy
    def _sk_component_info(:in_ports), do: [:input]
    def _sk_component_info(:out_ports), do: [:output]

    def _sk_component_initial_state, do: 42

    def _sk_callback_list, do: [example: 1]

    def _sk_callback_info(:example, 1) do
      %Info{read?: true, write?: false, emit?: true}
    end

    def example(state, config, arg) do
      result = state * config
      %Result{state: state, emit: [arg: arg], result: result}
    end
  end
  ```
  """

  alias Skitter.{Port, Strategy, Invocation, Component.Callback.Info}

  # ----- #
  # Types #
  # ----- #

  @typedoc """
  A component is defined as a module.

  This module should implement the `Skitter.Component` behaviour.
  """
  @type t :: module()

  @typedoc """
  Arguments passed to a callback when it is called.

  The arguments are wrapped in a list.
  """
  @type args :: [any()]

  @typedoc """
  State passed to the callback when it is called.
  """
  @type state :: any()

  @typedoc """
  Configuration passed to the callback when it is called.

  The configuration represents the immutable state of a component. It is explicitly separated from
  the mutable `t:state/0` to enable strategies to explicitly differentiate between handling
  mutable and immutable data.
  """
  @type config :: any()

  @typedoc """
  Output emitted by a callback.

  Emitted data is returned as a list where the output for each out port is specified. When no data
  is emitted on a port, the port should be omitted from the emit list. The data emitted by a
  callback for a port should always be wrapped in a list. Each element in this list will be sent
  to downstream components separately.
  """
  @type emit :: [{Port.t(), [any()]}]

  @typedoc """
  Values returned by a callback when it is called.

  The following information is stored:

  - `:result`: The actual result of the callback, i.e. the final value returned in its body.
  - `:state`: The (possibly modified) state after calling the callback.
  - `:emit`: The list of output emitted by the callback.
  """
  @type result :: %__MODULE__.Callback.Result{
          result: any(),
          state: state(),
          emit: emit()
        }

  @typedoc """
  Additional callback information. Can be retrieved with `info/2`.

  The following information is stored:

  - `:read?`: Boolean which indicates if the callback reads the component state.
  - `:write?`: Boolean which indicates if the callback updates the component state.
  - `:emit`: Boolean which indicates if the callback emits data.
  """
  @type info :: %__MODULE__.Callback.Info{
          read?: boolean(),
          write?: boolean(),
          emit?: boolean()
        }

  # Struct Definitions
  # ------------------

  defmodule Callback do
    @moduledoc false

    defmodule Result do
      @moduledoc false
      defstruct [:state, :emit, :result]
    end

    defmodule Info do
      @moduledoc false
      defstruct read?: false, write?: false, emit?: false
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
  to emit data.

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

  @doc """
  Returns the initial state of the component.

  This function returns an initial state for the component. The state of a component is component
  specific: Skitter places no constraints on this state.
  """
  @callback _sk_component_initial_state() :: any()

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
  Create the initial state for `component`.

  ## Examples

      iex> initial_state(ComponentModule)
      42
  """
  @spec initial_state(t()) :: state()
  def initial_state(component), do: component._sk_component_initial_state()

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
  Get the index of an in port.

  ## Examples

      iex> in_port_to_index(ComponentModule, :input)
      0
      iex> in_port_to_index(ComponentModule, :other)
      nil
  """
  @spec in_port_to_index(t(), Port.t()) :: Port.index() | nil
  def in_port_to_index(component, port) do
    component |> in_ports() |> Enum.find_index(&(&1 == port))
  end

  @doc """
  Get the index of an out port.

  ## Examples

      iex> out_port_to_index(ComponentModule, :output)
      0
      iex> out_port_to_index(ComponentModule, :other)
      nil
  """
  @spec out_port_to_index(t(), Port.t()) :: Port.index() | nil
  def out_port_to_index(component, port) do
    component |> out_ports() |> Enum.find_index(&(&1 == port))
  end

  @doc """
  Convert an index of an in port to a port name.

  ## Examples

      iex> index_to_in_port(ComponentModule, 0)
      :input
      iex> index_to_in_port(ComponentModule, 1)
      nil
  """
  @spec index_to_in_port(t(), Port.index()) :: Port.t() | nil
  def index_to_in_port(component, idx), do: component |> in_ports() |> Enum.at(idx)

  @doc """
  Convert an index of an out port to a port name.

  ## Examples

      iex> index_to_out_port(ComponentModule, 0)
      :output
      iex> index_to_out_port(ComponentModule, 1)
      nil
  """
  @spec index_to_out_port(t(), Port.index()) :: Port.t() | nil
  def index_to_out_port(component, idx), do: component |> out_ports() |> Enum.at(idx)

  @doc """
  Generate a `t:emit/0` which emits the given message to all out ports.

  This function creates an emit list which will send `message` to each out port of `component`.
  The message will be wrapped with `Skitter.Invocation.meta/0` and should be published by using
  `:emit_invocation` inside `c:Skitter.Strategy.Component.receive/4`.
  """
  @spec meta_message_for_all_ports(t(), any()) :: emit()
  def meta_message_for_all_ports(component, message) do
    component
    |> out_ports()
    |> Enum.map(&({&1, [{message, Invocation.meta()}]}))
  end

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
      %Info{read?: true, write?: false, emit?: true}

  """
  @spec callback_info(t(), atom(), arity()) :: info()
  def callback_info(component, name, arity), do: component._sk_callback_info(name, arity)

  @doc """
  Call callback `callback_name` with `state`, `config` and `arguments`.

  ## Examples

      iex> call(ComponentModule, :example, 10, 2, [:foo])
      %Skitter.Component.Callback.Result{state: 10, result: 20, emit: [arg: :foo]}
  """
  @spec call(t(), atom(), state(), config(), args()) :: result()
  def call(component, name, state, config, args) do
    apply(component, name, [state, config | args])
  end

  @doc """
  Call callback `callback_name` with an empty state, `config` and `arguments`.

  This function calls `Skitter.Component.call/5` with the state created by `initial_state/1`. If
  `config` is omitted, it will be passed as `nil`.

  ## Examples

      iex> call(ComponentModule, :example, 2, [:foo])
      %Skitter.Component.Callback.Result{state: 42, result: 84, emit: [arg: :foo]}
  """
  @spec call(t(), atom(), config(), args()) :: result()
  def call(component, callback_name, config \\ nil, args) do
    call(component, callback_name, initial_state(component), config, args)
  end
end
