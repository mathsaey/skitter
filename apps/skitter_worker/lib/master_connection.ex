# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Worker.MasterConnection do
  @moduledoc """
  Handle connection to skitter masters.

  This module is responsible for connecting a worker runtime to a master. This
  can be done in two ways:

  - `start_link/1` can be called with a `master` argument.
  - `connect/1` is called
  """
  use GenServer
  require Logger

  alias Skitter.{Runtime, Worker}

  # --- #
  # API #
  # --- #

  @doc """
  Start the masterconnection, potentially connecting to `master`

  If `master` is nil, node connection is attempted. If `master` is a node,
  the spawned `GenServer` will attempt to connect to `master`. If the
  connection is not successfull for any reason, a message is logged but the
  spawned `GenServer` does not exit.
  """
  @spec start_link(node() | nil) :: GenServer.on_start()
  def start_link(master) do
    GenServer.start_link(__MODULE__, master, name: __MODULE__)
  end

  @doc """
  Attempt to connect to to `master`

  Asks the `MasterConnection` `GenServer` to connect to `master`. If this fails
  for any reason, an `{:error, reason}` tuple is returned. `reason` can be any
  reason returned by `Skitter.Runtime.Beacon.discover/1`, but it can also be:

  - `:not_master`: if `master` is not a skitter master
  - `:already_connected`: if this worker is already connected to a different
    master runtime. Attempting to connect to the same master again does not
    produce an error.

  `:ok` is returned if the connection is successful.
  """
  @spec connect(node()) :: :ok | {:error, any()}
  def connect(master) do
    GenServer.call(__MODULE__, {:connect, master})
  end

  # ------ #
  # Server #
  # ------ #

  @master_srv Skitter.Master.WorkerConnection
  @master_msg :connect

  defp do_connect(master) do
    with {:ok, :skitter_master} <- Runtime.discover(master),
         :ok <- GenServer.call({@master_srv, master}, {@master_msg, Node.self()}) do
      Logger.info("Connected to master: `#{master}`")
      Node.monitor(master, true)
      {:ok, master}
    else
      {:error, error} -> {:error, error}
      {:ok, _mode} -> {:error, :not_master}
    end
  end

  @impl true
  def init(master) do
    Runtime.publish(:skitter_worker)

    case master do
      nil -> {:ok, nil}
      any -> {:ok, nil, {:continue, any}}
    end
  end

  @impl true
  def handle_continue(master, nil) do
    state =
      case do_connect(master) do
        {:ok, master} ->
          master

        {:error, error} ->
          Logger.info("Could not connect to `#{master}`: #{error}")
          nil
      end

    {:noreply, state}
  end

  @impl true
  def handle_call({:connect, master}, _, nil) do
    case do_connect(master) do
      {:ok, master} -> {:reply, :ok, master}
      {:error, error} -> {:reply, {:error, error}, nil}
    end
  end

  def handle_call({:connect, master}, _, master), do: {:reply, :ok, master}
  def handle_call({:connect, _}, _, cur), do: {:reply, {:error, :already_connected}, cur}

  @impl true
  def handle_info({:nodedown, master}, master) do
    Logger.info("Master `#{master}` disconnected")

    if Worker.get_env(:shutdown_with_master, true) do
      Logger.info("Lost connection to master, shutting down...")
      System.stop()
    end

    {:noreply, nil}
  end
end
