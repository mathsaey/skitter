# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Worker.MasterConnection do
  @moduledoc """
  """
  use GenServer
  require Logger

  alias Skitter.{Runtime, Worker}

  # --- #
  # API #
  # --- #

  def start_link(master) do
    GenServer.start_link(__MODULE__, master, name: __MODULE__)
  end

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
