# Copyright 2018, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Nodes do
  @moduledoc false

  alias __MODULE__.{Registry, Notifier, LoadBalancer}
  alias Skitter.Task.Supervisor, as: STS

  # ------------ #
  # Registration #
  # ------------ #

  @doc """
  List all nodes.
  """
  def all(), do: MapSet.to_list(GenServer.call(Registry, :all))

  @doc """
  Connect to a (list of) skitter worker node(s).

  Returns true if successful. When not successful, an error or a list of errors
  is returned instead.
  """
  def connect([]), do: true

  def connect(nodes) when is_list(nodes) do
    lst =
      nodes
      |> Enum.map(&connect/1)
      |> Enum.reject(&(&1 == true))
    lst == [] || lst
  end

  def connect(node), do: GenServer.call(Registry, {:connect, node})

  def disconnect(node) do
    GenServer.cast(Registry, {:disconnect, node})
    Skitter.Runtime.Worker.remove_master(node)
  end

  # ------------- #
  # Notifications #
  # ------------- #

  @doc """
  Subscribe to node join events.

  When a node joins the network, the pid that called this function will
  receive `{:node_join, node}`.
  """
  def subscribe_join do
    GenServer.cast(Notifier, {:subscribe, self(), :node_join})
  end

  @doc """
  Subscribe to node leave events.

  When a node leaves the network, the pid that called this function will
  receive `{:node_leave, node, reason}`.
  When the node was disconnected through `Nodes.disconnect`, the provided reason
  will be `:removed`.
  """
  def subscribe_leave do
    GenServer.cast(Notifier, {:subscribe, self(), :node_leave})
  end

  @doc """
  Unsubscribe from join events.

  The pid will receive no further notifications when a node joins the network.
  """
  def unsubscribe_join do
    GenServer.cast(Notifier, {:unsubscribe, self(), :node_join})
  end

  @doc """
  Unsubscribe from leave events.

  The pid will receive no further notifications when a node leaves the network.
  """
  def unsubscribe_leave do
    GenServer.cast(Notifier, {:unsubscribe, self(), :node_leave})
  end

  # ----- #
  # Tasks #
  # ----- #

  @doc """
  Execute `{mod, func, args}` on `node`, block until a result is available.
  """
  def on(node, mod, func, args), do: hd(on_many([node], mod, func, args))

  @doc """
  Execute `{mod, func, args}` on every node, obtain the results in a list.
  """
  def on_all(mod, func, args), do: on_many(all(), mod, func, args)

  @doc """
  Start a permanent task on a node selected by the load balancer.
  """
  def on_permanent(mod, func, args) do
    on(select_permanent(), mod, func, args)
  end

  @doc """
  Start a transient task on a node selected by the load balancer.
  """
  def on_transient(mod, func, args) do
    on(select_transient(), mod, func, args)
  end

  defp on_many(nodes, mod, func, args) do
    nodes
    |> Enum.map(&Task.Supervisor.async({STS, &1}, mod, func, args))
    |> Enum.map(&Task.await(&1))
  end

  # -------------- #
  # Load Balancing #
  # -------------- #

  def select_permanent(), do: GenServer.call(LoadBalancer, :permanent)
  def select_transient(), do: GenServer.call(LoadBalancer, :transient)
end
