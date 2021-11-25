# Copyright 2018 - 2021, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.ConstantStore do
  @moduledoc false
  # This module is used to store constant data on the various nodes of the cluster.
  # It uses persistent_term under the hood, so it should not be used to manage mutable data.

  alias Skitter.Runtime.Registry

  @type ref() :: {atom(), reference()}

  @spec put([any()], atom(), reference()) :: ref()
  def put(term, atom, ref) do
    :persistent_term.put({atom, ref}, List.to_tuple(term))
    {atom, ref}
  end

  @spec put_everywhere([any()], atom(), reference()) :: ref()
  def put_everywhere(term, atom, ref) do
    put(term, atom, ref)
    Registry.on_all(__MODULE__, :put, [term, atom, ref]) |> hd()
  end

  @spec get_all(atom(), reference()) :: [any()]
  def get_all(atom, ref) do
    {atom, ref}
    |> :persistent_term.get()
    |> Tuple.to_list()
  end

  defmacro get(atom, ref, idx) do
    quote do
      :persistent_term.get({unquote(atom), unquote(ref)}) |> elem(unquote(idx))
    end
  end
end
