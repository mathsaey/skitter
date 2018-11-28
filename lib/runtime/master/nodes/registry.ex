# Copyright 2018, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Master.Nodes.Registry do
  @moduledoc false

  use Agent

  # --- #
  # API #
  # --- #

  def start_link(_) do
    Agent.start_link(__MODULE__, :init, [], name: __MODULE__)
  end

  def register(node, pid) do
    Agent.update(__MODULE__, __MODULE__, :update, [node, pid], :infinity)
  end

  def unregister(node) do
    Agent.update(__MODULE__, __MODULE__, :remove, [node], :infinity)
  end

  def server(node) do
    Agent.get(__MODULE__, __MODULE__, :fetch, [node], :infinity)
  end

  def registered do
    Agent.get(__MODULE__, __MODULE__, :nodes, [], :infinity)
  end

  # --------- #
  # Callbacks #
  # --------- #

  def init(), do: %{}
  def nodes(map), do: Map.keys(map)
  def fetch(map, node), do: Map.get(map, node)
  def remove(map, node), do: Map.delete(map, node)
  def update(map, node, pid), do: Map.put(map, node, pid)
end
