# Copyright 2018 - 2022, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Mode.Master.WorkerConnection do
  @moduledoc """
  Module to manage connections with remote worker runtimes.

  This module contains code to connect to worker runtimes and to subscribe to messages about their
  status.
  """
  alias Skitter.{Config, Remote}
  alias __MODULE__.Notifier

  def connect, do: connect(Config.get(:workers, []))

  def connect(worker) when is_atom(worker), do: connect([worker])

  def connect(workers) when is_list(workers) do
    case do_connect(workers) do
      [] -> :ok
      lst -> {:error, lst}
    end
  end

  defp do_connect(workers) when is_list(workers) do
    workers
    |> Enum.map(&Task.async(fn -> {&1, Remote.connect(&1, :worker)} end))
    |> Enum.map(&Task.await(&1))
    |> Enum.reject(fn {_, ret} -> ret == {:ok, :worker} end)
    |> Enum.map(fn {node, {:error, error}} -> {node, error} end)
  end

  @doc """
  Subscribe to worker_up events.

  Every time a new worker is connected, the process that called this function
  will receive a `{:worker_up, worker, tags}` message.
  """
  @spec subscribe_up() :: :ok
  def subscribe_up(), do: GenServer.call(Notifier, {:subscribe, :worker_up})

  @doc """
  Subscribe to worker_up events on the remote node.

  Every time a new worker is connected, the process that called this function
  will receive a `{:worker_up, worker, tags}` message.
  """
  @spec subscribe_up(node()) :: :ok
  def subscribe_up(node) do
    GenServer.call({Notifier, node}, {:subscribe, :worker_up}, :infinity)
  end

  @doc """
  Subscribe to worker_down events.

  Every time a new worker disconnects, the process that called this function
  will receive a `{:worker_down, worker}` message.
  """
  @spec subscribe_down() :: :ok
  def subscribe_down(), do: GenServer.call(Notifier, {:subscribe, :worker_down})

  @doc """
  Subscribe to worker_down events on the remote node.

  Every time a new worker is connected, the process that called this function
  will receive a `{:worker_down, worker}` message.
  """
  @spec subscribe_down(node()) :: :ok
  def subscribe_down(node) do
    GenServer.call({Notifier, node}, {:subscribe, :worker_down}, :infinity)
  end

  @doc """
  Unsubscribe from all future worker_up events.
  """
  @spec unsubscribe_up() :: :ok
  def unsubscribe_up(), do: GenServer.cast(Notifier, {:unsubscribe, self(), :worker_up})

  @doc """
  Unsubscribe from all future worker_up events.
  """
  @spec unsubscribe_up(node()) :: :ok
  def unsubscribe_up(node) do
    GenServer.cast({Notifier, node}, {:unsubscribe, self(), :worker_up})
  end

  @doc """
  Unsubscribe from all future worker_down events.
  """
  @spec unsubscribe_down() :: :ok
  def unsubscribe_down(), do: GenServer.cast(Notifier, {:unsubscribe, self(), :worker_down})

  @doc """
  Unsubscribe from all future worker_up events.
  """
  @spec unsubscribe_down(node()) :: :ok
  def unsubscribe_down(node) do
    GenServer.cast({Notifier, node}, {:unsubscribe, self(), :worker_down})
  end
end
