# Copyright 2018, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Nodes do
  @moduledoc false
  # Facilities to work with nodes, intended to be used by a master node.

  alias Skitter.Runtime.TaskSupervisor, as: STS
  alias __MODULE__.{Registry, Notifier}

  # ------------ #
  # Registration #
  # ------------ #

  def all(), do: MapSet.to_list(GenServer.call(Registry, :all))

  @doc """
  Connect to a list of nodes.

  Returns a list of `{node, error}` pairs where `node` is the node that caused
  an issue and `error` is the `error` that was returned. Returns an empty list
  if no errors occurred.
  """
  def batch_connect(nodes) do
    nodes
    |> Enum.map(&Task.Supervisor.async(STS, fn -> {&1, connect(&1)} end))
    |> Enum.map(&Task.await(&1))
    |> Enum.reject(fn {_, ret} -> ret == :ok end)
    |> Enum.map(fn {node, {:error, error}} -> {node, error} end)
  end

  @doc """
  Connect to a single node.

  Returns `:ok` if the connection succeeded, `{:error, reason}` otherwise.
  The possible reasons are documented in `t:Skitter.connection_error/0`
  """
  def connect(node), do: GenServer.call(Registry, {:connect, node})

  def disconnect(node), do: GenServer.call(Registry, {:disconnect, node})

  # ------------- #
  # Notifications #
  # ------------- #

  @doc """
  Subscribe to node join and leave events.

  See `subscribe_join/0` and `subscribe_leave`.
  """
  def subscribe_all do
    subscribe_join()
    subscribe_leave()
  end

  @doc """
  Unsubscribe from all node join and leave events.

  See `unsubscribe_join/0` and `unsubscribe_leave`.
  """
  def unsubscribe_all do
    unsubscribe_join()
    unsubscribe_leave()
  end

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

  defp on_many(nodes, mod, func, args) do
    nodes
    |> Enum.map(&Task.Supervisor.async({STS, &1}, mod, func, args))
    |> Enum.map(&Task.await(&1))
  end
end
