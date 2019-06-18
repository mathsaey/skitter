# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Component.State do
  @moduledoc """
  State of a component instance.

  Each component instance has the ability to store some state.
  Internally, this state is represented as a map between field names and their
  associate data.
  """

  @typedoc """
  State of a component instance.
  """
  @type t :: %{optional(field()) => any()}

  @typedoc """
  Data storage "slot" of a component.

  The state of a component instance is divided into various named slots.
  In skitter, these slots are called _fields_. The fields of a component
  are statically defined and are stored as atoms.
  """
  @type field :: atom()

  @doc """
  Create the initial state map based on a list of fields.

  Each field is initialized to nil.

  ## Examples

      iex> create([:foo, :bar])
      %{foo: nil, bar: nil}
      iex> create([])
      %{}
  """
  @spec create([field()]) :: t()
  def create(fields), do: Map.new(fields, &{&1, nil})

  @doc """
  Fetch a value from the state map.

  ## Examples

      iex> read(%{foo: 5}, :foo)
      5
      iex> read(%{foo: 5}, :bar)
      ** (KeyError) key :bar not found in: %{foo: 5}

  """
  @spec read(t(), field()) :: any()
  def read(state, field), do: Map.fetch!(state, field)

  @doc """
  Update a value of the component state. The field must already exist.

  ## Examples
      iex> update(%{foo: 5}, :foo, 10)
      %{foo: 10}
      iex> update(%{foo: 5}, :bar, 10)
      ** (KeyError) key :bar not found

  """
  @spec update(t(), field(), any()) :: t()
  def update(state, field, value), do: %{state | field => value}
end
