# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.DSL.Registry do
  @moduledoc false
  # Private functions to resolve component and workflow names

  alias Skitter.DSL.DefinitionError
  use Agent

  def start_link(_), do: Agent.start_link(fn -> %{} end, name: __MODULE__)

  def put_if_named(e = %{name: nil}), do: e

  def put_if_named(e = %{name: n}) do
    case Agent.get_and_update(__MODULE__, __MODULE__, :insert, [n, e]) do
      :duplicate -> raise DefinitionError, "`#{n}` is already in use"
      :ok -> e
    end
  end

  def get(key), do: Agent.get(__MODULE__, &Map.get(&1, key))

  def get_all, do: Agent.get(__MODULE__, &Map.to_list(&1))
  def get_names, do: Agent.get(__MODULE__, &Map.keys(&1))

  def insert(map, key, value) do
    if Map.has_key?(map, key) do
      {:duplicate, map}
    else
      {:ok, Map.put(map, key, value)}
    end
  end
end
