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

  @doc """
  Start the workers server, connecting to all nodes in `workers`.

  This function returns `{:ok, pid}` if the server managed to connect to every
  provided worker. If the server failed to connect to some workers,
  `{:error, list}` is returned. `list` is a list of `{worker, reason}` tuples.
  In this list, `worker` is the name of a worker that could not be connected
  to, while `reason` is the reason returned by `Skitter.Runtime.connect/3`.
  """
  @spec start_link([node()]) :: GenServer.on_start()
  def start_link(workers) do
    GenServer.start_link(__MODULE__, workers, name: __MODULE__)
  end

  @doc """
  Attempt to connect to `workers`.

  Asks the workers server to connect to all the provided nodes. When
  successful, `:ok` is returned. If this fails, `{:error, list}` is returned.
  `list` is a list of `{worker, reason}` tuples. Reason indicates the error that
  occurred when the server attempted to connect with `worker`.
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

  # ------ #
  # Server #
  # ------ #

  defp try_connect(worker) when is_atom(worker) do
    Runtime.connect(worker, :skitter_worker, Skitter.Worker.Master)
  end

  defp add_if_connected({worker, :ok}) do
    Node.monitor(worker, true)
    Registry.add(worker)
    {worker, :ok}
  end

  defp add_if_connected(any), do: any

  defp do_connect(workers) when is_list(workers) do
    workers
    |> Enum.map(&Task.Supervisor.async(TaskSupervisor, fn -> {&1, try_connect(&1)} end))
    |> Enum.map(&Task.await(&1))
    |> Enum.map(&add_if_connected/1)
    |> Enum.reject(fn {_, ret} -> ret == :ok end)
    |> Enum.map(fn {node, {:error, error}} -> {node, error} end)
  end

  @impl true
  def init(workers) do
    Registry.start_link()

    case do_connect(workers) do
      [] -> {:ok, nil}
      lst -> {:stop, lst}
    end
  end

  @impl true
  def handle_call({:connect, workers}, _, state) do
    case do_connect(workers) do
      [] -> {:reply, :ok, state}
      lst -> {:reply, {:error, lst}, state}
    end
  end

  def handle_call({:accept, worker}, _, state) do
    reply = Runtime.accept(worker, :skitter_worker)

    if reply do
      Node.monitor(worker, true)
      Registry.add(worker)
    end

    {:reply, reply, state}
  end

  @impl true
  def handle_info({:nodedown, worker}, state) do
    Logger.info("Worker `#{worker}` disconnected")
    Registry.remove(worker)
    # TODO: notifier
    {:noreply, state}
  end
end
