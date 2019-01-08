# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Nodes.Registry do
  @moduledoc false
  use Agent

  defstruct [:monitor, :connected]

  # --- #
  # API #
  # --- #

  def start_link(_) do
    Agent.start_link(__MODULE__, :init, [], name: __MODULE__)
  end

  def add(node) do
    Agent.update(__MODULE__, __MODULE__, :add, [node], :infinity)
  end

  def remove(node) do
    Agent.update(__MODULE__, __MODULE__, :remove, [node], :infinity)
  end

  def all, do: Agent.get(__MODULE__, __MODULE__, :all, [], :infinity)
  def get(node), do: Agent.get(__MODULE__, __MODULE__, :get, [node], :infinity)

  def update(node, kw) do
    Agent.update(__MODULE__, __MODULE__, :update, [node, kw], :infinity)
  end

  # --------- #
  # Callbacks #
  # --------- #

  def init(), do: %{}

  def add(map, node), do: Map.put(map, node, %__MODULE__{})
  def remove(map, node), do: Map.delete(map, node)

  def all(map), do: Map.keys(map)
  def get(map, node), do: Map.get(map, node)

  def update(map, node, kw) do
    Map.update(map, node, struct(__MODULE__, kw), fn s -> struct(s, kw) end)
  end
end
