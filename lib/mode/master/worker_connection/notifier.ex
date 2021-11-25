# Copyright 2018 - 2021, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Mode.Master.WorkerConnection.Notifier do
  @moduledoc false
  use GenServer
  alias Skitter.Nodes

  def start_link([]) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Subscribe to worker_up events.

  Every time a new worker is connected, the process that called this function
  will receive a `{:worker_up, worker, tags}` message.
  """
  @spec subscribe_up() :: :ok
  def subscribe_up(), do: GenServer.call(__MODULE__, {:subscribe, :worker_up})

  @doc """
  Subscribe to worker_up events on the remote node.

  Every time a new worker is connected, the process that called this function
  will receive a `{:worker_up, worker, tags}` message.
  """
  @spec subscribe_up(node()) :: :ok
  def subscribe_up(node) do
    GenServer.call({__MODULE__, node}, {:subscribe, :worker_up}, :infinity)
  end

  @doc """
  Subscribe to worker_down events.

  Every time a new worker disconnects, the process that called this function
  will receive a `{:worker_down, worker}` message.
  """
  @spec subscribe_down() :: :ok
  def subscribe_down(), do: GenServer.call(__MODULE__, {:subscribe, :worker_down})

  @doc """
  Subscribe to worker_down events on the remote node.

  Every time a new worker is connected, the process that called this function
  will receive a `{:worker_down, worker}` message.
  """
  @spec subscribe_down(node()) :: :ok
  def subscribe_down(node) do
    GenServer.call({__MODULE__, node}, {:subscribe, :worker_down}, :infinity)
  end

  @doc """
  Unsubscribe from all future worker_up events.
  """
  @spec unsubscribe_up() :: :ok
  def unsubscribe_up(), do: GenServer.cast(__MODULE__, {:unsubscribe, self(), :worker_up})

  @doc """
  Unsubscribe from all future worker_up events.
  """
  @spec unsubscribe_up(node()) :: :ok
  def unsubscribe_up(node) do
    GenServer.cast({__MODULE__, node}, {:unsubscribe, self(), :worker_up})
  end

  @doc """
  Unsubscribe from all future worker_down events.
  """
  @spec unsubscribe_down() :: :ok
  def unsubscribe_down(), do: GenServer.cast(__MODULE__, {:unsubscribe, self(), :worker_down})

  @doc """
  Unsubscribe from all future worker_up events.
  """
  @spec unsubscribe_down(node()) :: :ok
  def unsubscribe_down(node) do
    GenServer.cast({__MODULE__, node}, {:unsubscribe, self(), :worker_down})
  end

  @doc """
  Notify subscribers a node has joined the cluster.
  """
  @spec notify_up(node(), Nodes.tag()) :: :ok
  def notify_up(worker, tags), do: GenServer.cast(__MODULE__, {:worker_up, worker, tags})

  @doc """
  Notify subscribers a node has left the cluster.
  """
  @spec notify_down(node()) :: :ok
  def notify_down(worker), do: GenServer.cast(__MODULE__, {:worker_down, worker})

  # --------- #
  # Genserver #
  # --------- #

  @impl true
  def init([]) do
    {:ok, %{}}
  end

  @impl true
  def handle_call({:subscribe, topic}, {pid, _}, state) do
    state = Map.update(state, topic, MapSet.new([pid]), &MapSet.put(&1, pid))
    {:reply, :ok, state}
  end

  @impl true
  def handle_cast({:unsubscribe, pid, topic}, state) do
    state = Map.update(state, topic, MapSet.new(), &MapSet.delete(&1, pid))
    {:noreply, state}
  end

  def handle_cast(tuple = {:worker_up, _, _}, state) do
    notify(:worker_up, tuple, state)
    {:noreply, state}
  end

  def handle_cast(tuple = {:worker_down, _}, state) do
    notify(:worker_down, tuple, state)
    {:noreply, state}
  end

  defp notify(topic, tuple, topics) do
    topics |> Map.get(topic, MapSet.new()) |> MapSet.to_list() |> Enum.each(&send(&1, tuple))
  end
end
