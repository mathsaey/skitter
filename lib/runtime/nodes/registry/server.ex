# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Nodes.Registry.Server do
  @moduledoc false

  use GenServer
  require Logger

  alias Skitter.Runtime.Nodes

  # TODO: Rediscover connected nodes after crash

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_) do
    :ok = :net_kernel.monitor_nodes(true, node_type: :visible)
    {:ok, MapSet.new()}
  end

  @impl true
  def handle_call(:all, _, set) do
    {:reply, set, set}
  end

  def handle_call({:connect, node}, _, set) do
    {reply, set} = connect(node, set)
    {:reply, reply, set}
  end

  @impl true
  def handle_info({:nodeup, node, _}, set) do
    Logger.warn "Attempting to connect to discovered node", node: node
    {_, set} = connect(node, set)
    {:noreply, set}
  end

  def handle_info({:nodedown, node, _}, set) do
    Logger.warn "Node down", node: node
    {:noreply, MapSet.delete(set, node)}
  end

  defp connect(node, set) do
    case Nodes.Registry.Connect.connect(node) do
      {:ok, node} ->
        Nodes.Notifier.notify_join(node)
        receive(do: ({:nodeup, ^node, _} -> node))
        {true, MapSet.put(set, node)}

      {:local, node} ->
        Nodes.Notifier.notify_join(node)
        {true, MapSet.put(set, node)}

      {error, node} ->
        {{error, node}, set}
    end
  end
end
