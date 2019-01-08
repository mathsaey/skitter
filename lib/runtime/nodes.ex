# Copyright 2018, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Nodes do
  @moduledoc false
  alias __MODULE__

  def supervisor(:worker), do: Nodes.WorkerSupervisor
  def supervisor(:master), do: Nodes.MasterSupervisor

  @doc """
  List all nodes.
  """
  def all, do: Nodes.Registry.all()

  @doc """
  Subscribe to a node.

  When the node goes down, `pid` will receive `{:node_down, node, reason}`
  message. The reason is `:normal` in the case of a planned shutdown.
  """
  defdelegate subscribe(node, pid), to: Nodes.Monitor

  @doc """
  Unsubscribe.

  The pid will receive no notifications if the node goes down.
  """
  defdelegate unsubscribe(node, pid), to: Nodes.Monitor

  @doc """
  Execute `{mod, func, args}` on `node`, block until a result is available.
  """
  defdelegate on(node, mod, func, args), to: Nodes.Task

  @doc """
  Execute `{mod, func, args}` on every node, obtain the results in a list.
  """
  defdelegate on_all(mod, func, args), to: Nodes.Task

  def on_permanent(mod, func, args) do
    Nodes.Task.on(Nodes.LoadBalancer.select_permanent(), mod, func, args)
  end

  def on_transient(mod, func, args) do
    Nodes.Task.on(Nodes.LoadBalancer.select_transient(), mod, func, args)
  end

  @doc """
  Add a node or list of nodes.

  The given node will be monitored, processes can subscribe to be notified if
  the node crashes.
  """
  def add(node), do: connect(node)



  # @doc """
  # Unregister the node and remove all connections.

  # All subscribers will be notified that the node shut down with reason `:normal`
  # """
  # def remove(node) do
  #   Nodes.Monitor.remove(get(node))
  #   Worker.unregister_master(node, Node.self())
  # end

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
         {:ok, pid} <- Nodes.MonitorSupervisor.start_monitor(node),
         :ok <- Nodes.Registry.register(node, pid) do
      # Logger.info("Registered new worker: #{node}")
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
