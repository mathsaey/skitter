# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Nodes.Worker do
  @moduledoc false

  use GenServer
  require Logger

  # --- #
  # API #
  # --- #

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Get the current master node
  """
  def master, do: GenServer.call(__MODULE__, :master, :infinity)

  @doc """
  Connect to node `master`.

  If `master` has `Skitter.Runtime.Configuration.automatic_connect?/0` enabled,
  it will automatically use this node as a worker node. Returns `:ok` if the
  connection was successful, an `{:error, reason}` tuple otherwise.
  """
  def connect_to_master(master) do
    GenServer.call(__MODULE__, {:connect_master, master}, :infinity)
  end

  @doc """
  Ask the worker at `node` to add the current node (a master) as its master.
  """
  def register_master(node) do
    GenServer.call({__MODULE__, node}, {:add_master, Node.self()}, :infinity)
  end

  @doc """
  Ask the worker at `node` to remove the current node (a master) as its master.
  """
  def remove_master(node) do
    GenServer.call({__MODULE__, node}, {:remove_master, Node.self()}, :infinity)
  end

  @doc """
  Check if `node` is a skitter worker node.
  """
  def verify_worker(node) do
    !is_nil(:rpc.call(node, GenServer, :whereis, [__MODULE__]))
  end

  # ------ #
  # Server #
  # ------ #

  @impl true
  def init(_) do
    {:ok, nil}
  end

  @impl true
  def handle_call(:master, _, master) do
    {:reply, master, master}
  end

  def handle_call({:connect_master, master}, _, nil) do
    Logger.info("Requestion connection to master: #{master}")

    reply =
      case Node.connect(master) do
        :ignored -> {:error, :not_distributed}
        false -> {:error, :not_connected}
        true -> :ok
      end

    {:reply, reply, nil}
  end

  def handle_call({:add_master, master}, _, nil) do
    Logger.info("Registering master: #{master}")
    {:reply, :ok, master}
  end

  def handle_call({:remove_master, master}, _, master) do
    Logger.info("Removing master: #{master}")
    {:reply, :ok, nil}
  end
end
