# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

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
  elixir struct (`@t:t/0`) along with some utilities to modify and query
  reactive components.
  """

  alias Skitter.Port
  alias Skitter.Component.{Callback, State}

  defstruct name: nil,
            fields: [],
            in_ports: [],
            out_ports: [],
            callbacks: %{}

  @typedoc """
  A component is defined as a collection of _metadata_ and _callbacks_.

  The metadata provides additional information about a component, while the
  various `Skitter.Component.Callback` implement the functionality of a
  component.

  The following metadata is stored:

  | Name          | Description                        | Default |
  | ------------- | ---------------------------------- | ------- |
  | `name`        | The name of the component          | `nil`   |
  | `fields`      | List of the slots of the component | `[]`    |
  | `in_ports`    | List of in ports of the component. | `[]`    |
  | `out_ports`   | List of out ports of the component | `[]`    |

  Note that a valid component must have at least one in port.
  """
  @type t :: %__MODULE__{
          name: String.t() | nil,
          fields: [State.field()],
          in_ports: [Port.t(), ...],
          out_ports: [Port.t()],
          callbacks: %{optional(callback_name()) => Callback.t()}
        }

  @typedoc """
  Callback identifiers.

  The callbacks of a skitter component are named.
  These names are stored as atoms.
  """
  @type callback_name :: atom()

  @doc """
  Call a specific callback of the component.

  Call the callback named `callback_name` of `component` with the arguments
  defined in `t:Skitter.Component.Callback.signature/0`.

  ## Examples

      iex> cb = Callback.create(fn s, [a] -> {:ok, s, nil, a} end, :read, false)
      iex> component = %Component{callbacks: %{f: cb}}
      iex> call(component, :f, %{field: 5}, [10])
      {:ok, %{field: 5}, nil, 10}
  """
  @spec call(t(), callback_name(), State.t(), [any()]) :: Callback.result()
  def call(component = %__MODULE__{}, callback_name, state, arguments) do
    Callback.call(component.callbacks[callback_name], state, arguments)
  end

  @doc """
  Create an initial `t:Skitter.Component.State.t/0` for a given component.

  ## Examples

      iex> create_empty_state(%Component{fields: [:a_field, :another_field]})
      %{a_field: nil, another_field: nil}
      iex> create_empty_state(%Component{fields: []})
      %{}
  """
  @spec create_empty_state(t()) :: State.t()
  def create_empty_state(%__MODULE__{fields: fields}), do: State.create(fields)
end
