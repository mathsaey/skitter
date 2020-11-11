# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Master.WorkerConnection.Notifier do
  @moduledoc false
  use GenServer

  def start_link([]) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Subscribe to worker_up events.

  Every time a new worker is connected, the process that called this function
  will receive a `{:worker_up, worker}` message.
  """
  @spec subscribe_up() :: :ok
  def subscribe_up(), do: GenServer.cast(__MODULE__, {:subscribe, self(), :worker_up})

  @doc """
  Subscribe to worker_down events.

  Every time a new worker disconnects, the process that called this function
  will receive a `{:worker_down, worker}` message.
  """
  @spec subscribe_down() :: :ok
  def subscribe_down(), do: GenServer.cast(__MODULE__, {:subscribe, self(), :worker_down})

  @doc """
  Unsubscribe from all future worker_up events.
  """
  @spec unsubscribe_up() :: :ok
  def unsubscribe_up(), do: GenServer.cast(__MODULE__, {:unsubscribe, self(), :worker_up})

  @doc """
  Unsubscribe from all future worker_down events.
  """
  @spec unsubscribe_down() :: :ok
  def unsubscribe_down(), do: GenServer.cast(__MODULE__, {:unsubscribe, self(), :worker_down})

  @doc """
  Notify subscribers a node has joined the cluster.
  """
  @spec notify_up(node()) :: :ok
  def notify_up(worker), do: GenServer.cast(__MODULE__, {:notify, :worker_up, worker})

  @doc """
  Notify subscribers a node has left the cluster.
  """
  @spec notify_down(node()) :: :ok
  def notify_down(worker), do: GenServer.cast(__MODULE__, {:notify, :worker_down, worker})

  # --------- #
  # Genserver #
  # --------- #

  @impl true
  def init([]) do
    {:ok, %{}}
  end

  @impl true
  def handle_cast({:subscribe, pid, topic}, state) do
    state = Map.update(state, topic, MapSet.new([pid]), &MapSet.put(&1, pid))
    {:noreply, state}
  end

  def handle_cast({:unsubscribe, pid, topic}, state) do
    state = Map.update(state, topic, MapSet.new(), &MapSet.delete(&1, pid))
    {:noreply, state}
  end

  def handle_cast({:notify, topic, worker}, state) do
    state
    |> Map.get(topic, MapSet.new())
    |> MapSet.to_list()
    |> Enum.each(&send(&1, {topic, worker}))

    {:noreply, state}
  end
end
