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
  alias Skitter.Component.Callback

  defstruct name: nil,
            description: "",
            in_ports: [],
            out_ports: [],
            fields: [],
            callbacks: %{}

  @typedoc """
  A component is defined as a collection of _metadata_ and _callbacks_.

  The metadata provides additional information about a component, while the
  various `Skitter.Component.Callback` implement the functionality of a
  component. Besides these, the component struct stores some precomputed
  data for optimization purposes.

  The following metadata is stored:

  | Name          | Description                        | Default |
  | ------------- | ---------------------------------- | ------- |
  | `name`        | The name of the component          | `nil`   |
  | `description` | Description of the component       | `""`    |
  | `in_ports`    | List of in ports of the component. | `[]`    |
  | `out_ports`   | List of out ports of the component | `[]`    |
  | `fields`      | List of the slots of the component | `[]`    |

  Note that a valid component must have at least one in port.
  """
  @type t :: %__MODULE__{
          name: String.t() | nil,
          description: String.t(),
          in_ports: [port_name(), ...],
          out_ports: [port_name()],
          fields: [field_name],
          callbacks: %{optional(callback_name()) => Callback.t()}
        }

  @typedoc """
  Input/output interface of a component.

  The ports of a component define how it can receive data from the workflow,
  and how it can publish data to the workflow.
  The name of a port is a part of the definition of a component, and is stored
  as an atom.
  """
  @type port_name :: atom()

  @typedoc """
  Data storage mechanism of a component.

  The fields of a component can be used to store the state of a component
  instance at runtime.
  The names of these fields are part of the definition of a component, and are
  stored as atoms.
  """
  @type field_name :: atom()

  @typedoc """
  Callback identifiers.

  The callbacks of a skitter component are named.
  These names are stored as atoms.
  """
  @type callback_name :: atom()

  @typedoc """
  State of a component instance.

  Each instance of a component has the ability to store some state.
  This state is represented as a map between field names and their associated
  data.
  """
  @type state :: %{optional(field_name()) => any()}

  @doc """
  Call a specific callback of the component.

  Call the callback named `callback_name` of `component` with the arguments
  defined in `t:state()`.

  ## Examples

      iex> cb = Callback.create(fn s, [_] -> {:ok, s, nil} end, :read, false)
      iex> component = %Component{callbacks: %{f: cb}}
      iex> call(component, :f, %{field: 5}, [10])
      {:ok, %{field: 5}, nil}
  """
  @spec call(t(), callback_name(), state(), [any()]) :: Calback.result()
  def call(component = %__MODULE__{}, callback_name, state, arguments) do
    Callback.call(component.callbacks[callback_name], state, arguments)
  end

  @doc """
  Create an initial state for a given component.

  This initial state is a map with a key for each field the component has.
  The value of each of these keys is `nil`.

  ## Examples

      iex> create_empty_state(%Component{fields: [:a_field, :another_field]})
      %{a_field: nil, another_field: nil}
      iex> create_empty_state(%Component{fields: []})
      %{}
  """
  @spec create_empty_state(t()) :: %{optional(field_name()) => nil}
  def create_empty_state(%__MODULE__{fields: fields}) do
    Map.new(fields, &{&1, nil})
  end
end
