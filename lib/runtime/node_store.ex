# Copyright 2018 - 2022, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.NodeStore do
  @moduledoc """
  Store constant data associated with operation nodes.

  This module is used to store constant data for the nodes in a workflow. Data is stored as a
  tuple. Each node knows its own index in this tuple, which enables constant-time access to
  any data stored in this store.

  This module uses `Skitter.Runtime.ConstantStore` under the hood. As such, it should _not_ be
  used to handle mutable data.
  """
  alias Skitter.Runtime.ConstantStore
  require ConstantStore

  @doc """
  Store a list of information inside the local node store.

  Data is implicitly converted to a tuple before insertion.
  """
  @spec put([any()], atom(), reference()) :: :ok
  def put(lst, atom, ref), do: ConstantStore.put(List.to_tuple(lst), atom, ref)

  @doc "Store data on the current node and all worker nodes."
  @spec put_everywhere([any()], atom(), reference()) :: :ok
  def put_everywhere(lst, atom, ref) do
    ConstantStore.put_everywhere(List.to_tuple(lst), atom, ref)
  end

  @doc """
  Get all data stored in a node store.
  """
  @spec get_all(atom(), reference()) :: [any()]
  def get_all(atom, ref), do: ConstantStore.get(atom, ref) |> Tuple.to_list()

  @doc "Fetch data from the store for the operation node at `idx`."
  defmacro get(atom, ref, idx) do
    quote do
      require Skitter.Runtime.ConstantStore
      Skitter.Runtime.ConstantStore.get(unquote(atom), unquote(ref)) |> elem(unquote(idx))
    end
  end
end
