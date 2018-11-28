# Copyright 2018, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Master.Nodes.Registry do
  use Agent

  def start_link(_) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  def register(node, pid) do
    Agent.update(__MODULE__, &(Map.put(&1, node, pid)), :infinity)
  end

  def unregister(node) do
    Agent.update(__MODULE__, &(Map.delete(&1, node)), :infinity)
  end

  def server(node) do
    Agent.get(__MODULE__, &(Map.get(&1, node)), :infinity)
  end

  def registered() do
    Agent.get(__MODULE__, &Map.keys(&1), :infinity)
  end
end
