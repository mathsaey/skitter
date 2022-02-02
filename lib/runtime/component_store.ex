# Copyright 2018 - 2022, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.ComponentStore do
  @moduledoc """
  Store constant data associated with components

  This module is used to store constant data for the components in a workflow. Data is stored as a
  tuple. Each component knows its own index in this tuple, which enables constant-time access to
  any data stored in this store.

  This module uses `:persistent_term`, so it should _not_ be used to manage mutable state.
  """
  alias Skitter.Remote

  @type ref() :: {module(), atom(), reference()}

  @doc """
  Store a list of information inside the local component store.

  Data is implicitly converted to a tuple before insertion.
  """
  @spec put([any()], atom(), reference()) :: :ok
  def put(term, atom, ref) do
    :persistent_term.put({__MODULE__, atom, ref}, List.to_tuple(term))
  end

  @doc """
  Store data on the current node and all worker nodes.
  """
  @spec put_everywhere([any()], atom(), reference()) :: :ok
  def put_everywhere(term, atom, ref) do
    put(term, atom, ref)
    Remote.on_all_workers(__MODULE__, :put, [term, atom, ref])
    :ok
  end

  @doc """
  Get all data stored in a component store.
  """
  @spec get_all(atom(), reference()) :: [any()]
  def get_all(atom, ref), do: Tuple.to_list(:persistent_term.get({__MODULE__, atom, ref}))

  @doc """
  Fetch data from the store for the component at `idx`.
  """
  defmacro get(atom, ref, idx) do
    quote do
      {unquote(__MODULE__), unquote(atom), unquote(ref)}
      |> :persistent_term.get()
      |> elem(unquote(idx))
    end
  end
end
