# Copyright 2018 - 2022, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.ConstantStore do
  @moduledoc """
  Store constant data.

  This module is used to store constant data on the various runtimes. This module uses
  `:persistent_term`. It should therefore _not_ be used to manage mutable state.
  """
  alias Skitter.Remote

  @type ref() :: {module(), atom(), reference()}

  @doc "Store information inside the local constant store."
  @spec put(any(), atom(), reference()) :: :ok
  def put(term, atom, ref), do: :persistent_term.put({__MODULE__, atom, ref}, term)

  @doc """
  Store data on all nodes.

  Should only be called from the master node.
  """
  @spec put_everywhere(any(), atom(), reference()) :: :ok
  def put_everywhere(term, atom, ref) do
    put(term, atom, ref)
    Remote.on_all_workers(__MODULE__, :put, [term, atom, ref])
    :ok
  end

  def remove(atom, ref), do: :persistent_term.erase({__MODULE__, atom, ref})

  @doc """
  Fetch data from the constant store.

  This is defined as a macro so it is inlined.
  """
  defmacro get(atom, ref) do
    quote(do: :persistent_term.get({unquote(__MODULE__), unquote(atom), unquote(ref)}))
  end
end
