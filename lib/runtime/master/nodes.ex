# Copyright 2018, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Master.Nodes do
  @moduledoc false

  alias Skitter.Runtime.Worker
  alias Skitter.Runtime.Master.Nodes

  @doc """
  Add a node or list of nodes.

  The given node will be monitored, processes can subscribe to be notified if
  the node crashes.
  """
  def add(node), do: connect(node)

  @doc """
  List of all connected nodes.
  """
  def all(), do: Nodes.Registry.registered()

  @doc """
  Unregister the node and remove all connections.

  All subscribers will be notified that the node shut down with reason `:normal`
  """
  def remove(node) do
    Nodes.Monitor.remove(get(node))
    Worker.unregister_master(node, Node.self())
  end

  @doc """
  Subscribe to a node.

  When the node goes down, `pid` will receive `{:node_down, node, reason}`
  message. The reason is `:normal` in the case of a planned shutdown.
  """
  def subscribe(node, pid \\ self()) do
    Nodes.Monitor.subscribe(get(node), pid)
  end

  @doc """
  Unsubscribe.

  The pid will receive no notifications if the node goes down.
  """
  def unsubscribe(node, pid \\ self()) do
    Nodes.Monitor.unsubscribe(get(node), pid)
  end

  defp get(node), do: Nodes.Registry.server(node)

  # --------------- #
  # Node Connection #
  # --------------- #

  defp connect([]), do: true

  defp connect(nodes) when is_list(nodes) do
    if Node.alive?() do
      lst =
        nodes
        |> Enum.map(&connect/1)
        |> Enum.reject(&(&1 == :ok))
      lst == [] || lst
    else
      :not_distributed
    end
  end

  defp connect(node) when is_atom(node) do
    with true <- Node.connect(node),
         true <- Worker.verify_node(node),
         :ok <- Worker.register_master(node, Node.self()),
         {:ok, _p} <- Nodes.MonitorSupervisor.start_monitor(node) do
      :ok
    else
      :already_connected -> {:already_connected, node}
      :not_connected -> {:not_connected, node}
      :invalid -> {:no_skitter_worker, node}
      false -> {:not_connected, node}
      any -> {:error, any, node}
    end
  end
end
