# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Master.Workers do
  @moduledoc """
  """
  use GenServer
  require Logger

  alias Skitter.Runtime
  alias Skitter.Runtime.TaskSupervisor

  alias __MODULE__.Registry

  # --- #
  # API #
  # --- #

  @doc """
  Start the workers server.
  """
  @spec start_link([]) :: GenServer.on_start()
  def start_link([]) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Attempt to connect to `workers`.

  Asks the workers server to connect to all the provided nodes. When
  successful, `:ok` is returned. If this fails, `{:error, list}` is returned.
  `list` is a list of `{worker, reason}` tuples. Reason indicates the error that
  occurred when the server attempted to connect with `worker`.

  Possible reasons are documented in `Skitter.Runtime.connect/3`.
  """
  @spec connect(node() | [node()]) :: :ok | {:error, [{node(), any()}]}
  def connect(worker) when is_atom(worker), do: connect([worker])

  def connect(workers) when is_list(workers) do
    GenServer.call(__MODULE__, {:connect, workers})
  end

  @doc """
  Get a list of all connected nodes.
  """
  @spec all() :: [node()]
  def all, do: Registry.all()

  @doc """
  Verify if `worker` is connected to this master.
  """
  @spec connected?(node()) :: boolean()
  def connected?(worker), do: Registry.connected?(worker)

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
  Execute `mod.func(args)` on `worker`, block until a result is available.
  """
  @spec on(node(), module(), atom(), [any()]) :: any()
  def on(worker, mod, func, args), do: hd(on_many([worker], mod, func, args))

  @doc """
  Execute `mod.func(args)` on every worker, obtain the results in a list.
  """
  @spec on_all(module(), atom(), [any()]) :: [any()]
  def on_all(mod, func, args), do: on_many(all(), mod, func, args)

  @doc """
  Execute `mod.func(args)` on every specified worker, obtain results in a list.
  """
  @spec on_many(node(), module(), atom(), [any()]) :: [any()]
  def on_many(workers, mod, func, args) do
    workers
    |> Enum.map(&Task.Supervisor.async({Skitter.Runtime.TaskSupervisor, &1}, mod, func, args))
    |> Enum.map(&Task.await(&1))
  end

  # ------------- #
  # Functionality #
  # ------------- #

  defp new_worker(worker, state) do
    Node.monitor(worker, true)
    Registry.add(worker)
    notify(:worker_up, worker, state)
  end

  defp try_connect(worker) when is_atom(worker) do
    Runtime.connect(worker, :skitter_worker, Skitter.Worker.Master)
  end

  defp add_if_connected({worker, :ok}, state) do
    new_worker(worker, state)
    {worker, :ok}
  end

  defp add_if_connected(any, _), do: any

  defp do_connect(workers, state) when is_list(workers) do
    workers
    |> Enum.map(&Task.Supervisor.async(TaskSupervisor, fn -> {&1, try_connect(&1)} end))
    |> Enum.map(&Task.await(&1))
    |> Enum.map(&add_if_connected(&1, state))
    |> Enum.reject(fn {_, ret} -> ret == :ok end)
    |> Enum.map(fn {node, {:error, error}} -> {node, error} end)
  end

  defp notify(topic, worker, subscriptions) do
    subscriptions
    |> Map.get(topic, MapSet.new())
    |> MapSet.to_list()
    |> Enum.each(&send(&1, {topic, worker}))
  end

  # --------- #
  # Genserver #
  # --------- #

  @impl true
  def init([]) do
    Runtime.publish(:skitter_master)
    Registry.start_link()
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

  @impl true
  def handle_call({:connect, workers}, _, state) do
    case do_connect(workers, state) do
      [] -> {:reply, :ok, state}
      lst -> {:reply, {:error, lst}, state}
    end
  end

  def handle_call({:accept, worker}, _, state) do
    reply = Runtime.accept(worker, :skitter_worker)
    if reply, do: new_worker(worker, state)
    {:reply, reply, state}
  end

  @impl true
  def handle_info({:nodedown, worker}, state) do
    Logger.info("Worker `#{worker}` disconnected")
    Registry.remove(worker)
    notify(:worker_down, worker, state)
    {:noreply, state}
  end
end
