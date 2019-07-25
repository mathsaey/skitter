# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Nodes.Registry do
  @moduledoc false

  use GenServer
  require Logger

  alias Skitter.Runtime.{Nodes, Configuration}

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
    if node in set do
      Logger.warn("Already connected to node", node: node)
      {:reply, {:error, :already_connected}, set}
    else
      {reply, set} = connect(node, set)
      {:reply, reply, set}
    end
  end

  def handle_call({:disconnect, node}, _, set) do
    if node in set do
      Logger.info("Disconnecting", node: node)
      Nodes.Connect.disconnect(node)
      Nodes.Notifier.notify_leave(node, :removed)
      {:reply, :ok, MapSet.delete(set, node)}
    else
      Logger.warn("Attempting to disconnect a non-connected node: #{node}")
      {:reply, :ok, set}
    end
  end

  @impl true
  def handle_info({:nodeup, node, _}, set) do
    if Configuration.automatic_connect?() and node not in set do
      Logger.info("Attempting connection with discovered node", node: node)
      {_, set} = connect(node, set)
      {:noreply, set}
    else
      {:noreply, set}
    end
  end

  def handle_info({:nodedown, node, _}, set) do
    if node in set do
      Logger.warn("Node down", node: node)
      Nodes.Notifier.notify_leave(node, :disconnect)
      {:noreply, MapSet.delete(set, node)}
    else
      {:noreply, set}
    end
  end

  defp connect(node, set) do
    case Nodes.Connect.connect(node) do
      :ok ->
        Logger.info("Connected to worker: #{node}")
        Nodes.Notifier.notify_join(node)
        {:ok, MapSet.put(set, node)}

      t = {:error, _} ->
        {t, set}
    end
  end
end
