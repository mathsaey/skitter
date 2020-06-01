# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Component do
  @moduledoc """
  Reactive Component definition and utilities.

  A Reactive Component is one of the core building blocks of skitter.
  It defines a single data processing step which can be embedded inside a
  reactive workflow.

  This module defines the internal representation of a skitter component as an
  elixir struct (`t:t/0`), some utilities to manipulate components and the
  `Access` behaviour for `t:t/0`. This behaviour can be used to access and
  modify a callback with a given name.
  """
  alias Skitter.{Port, Callback, Component, Strategy}

  @behaviour Access

  @typedoc """
  A component is defined as a collection of _metadata_ and _callbacks_.

  The metadata provides additional information about a component, while the
  various `Callback` implement the functionality of a component.

  The following metadata is stored:

  | Name          | Description                                  | Default   |
  | ------------- | -------------------------------------------- | --------- |
  | `name`        | The name of the component                    | `nil`     |
  | `fields`      | List of the slots of the component           | `[]`      |
  | `in_ports`    | List of in ports of the component.           | `[]`      |
  | `out_ports`   | List of out ports of the component           | `[]`      |
  | `strategy`    | The `t:Skitter.Strategy/0` of this component | `nil`     |

  Note that a valid component must have at least one in port.
  """
  @type t :: %__MODULE__{
          name: String.t() | nil,
          fields: [field()],
          in_ports: [Port.t(), ...],
          out_ports: [Port.t()],
          callbacks: %{optional(callback_name()) => Callback.t()},
          strategy: Strategy.t()
        }

  defstruct name: nil,
            fields: [],
            in_ports: [],
            out_ports: [],
            callbacks: %{},
            strategy: nil

  @typedoc """
  Data storage "slot" of a component.

  The state of a component instance is divided into various named slots.
  In skitter, these slots are called _fields_. The fields of a component
  are statically defined and are stored as atoms.
  """
  @type field :: atom()

  @typedoc """
  Callback identifiers.

  The callbacks of a skitter component are named.
  These names are stored as atoms.
  """
  @type callback_name :: atom()

  # --------- #
  # Utilities #
  # --------- #

  @doc """
  Call a specific callback of the component.

  Call the callback named `callback_name` of `component` with the arguments
  defined in `t:Callback.signature/0`.

  ## Examples

      iex> cb = %Callback{function: fn _, _ -> %Result{result: 10} end}
      iex> call(%Component{callbacks: %{f: cb}}, :f, %{}, [])
      %Callback.Result{state: nil, publish: nil, result: 10}
  """
  @spec call(t(), callback_name(), Callback.state(), [any()]) ::
          Callback.result()
  def call(component = %Component{}, callback_name, state, arguments) do
    Callback.call(component[callback_name], state, arguments)
  end

  @doc """
  Create an initial `t:Callback.state/0` for a given component.

  ## Examples

      iex> create_empty_state(%Component{fields: [:a_field, :another_field]})
      %{a_field: nil, another_field: nil}
      iex> create_empty_state(%Component{fields: []})
      %{}
  """
  @spec create_empty_state(Component.t()) :: Callback.state()
  def create_empty_state(%Component{fields: fields}) do
    Map.new(fields, &{&1, nil})
  end

  # Access
  # ------

  @impl true
  def fetch(comp, key), do: Access.fetch(comp.callbacks, key)

  @impl true
  def pop(comp, key) do
    {val, cbs} = Access.pop(comp.callbacks, key)
    {val, %{comp | callbacks: cbs}}
  end

  @impl true
  def get_and_update(comp, key, f) do
    {val, cbs} = Access.get_and_update(comp.callbacks, key, f)
    {val, %{comp | callbacks: cbs}}
  end
end

defimpl Inspect, for: Skitter.Component do
  use Skitter.Inspect, prefix: "Component", named: true

  ignore_short([:callbacks, :fields, :handler])
  ignore_empty([:fields, :out_ports])

  describe(:in_ports, "in")
  describe(:out_ports, "out")
end
