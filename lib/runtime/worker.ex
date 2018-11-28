# Copyright 2018, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Worker do
  @moduledoc false

  use GenServer

  require Logger

  # --- #
  # API #
  # --- #

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  # ---------- #
  # Remote API #
  # ---------- #

  def register_master(node, master) do
    GenServer.call({__MODULE__, node}, {:add_master, master}, :infinity)
  end

  def unregister_master(node, master) do
    GenServer.cast({__MODULE__, node}, {:remove_master, master})
  end

  def verify_node(node) do
    # Ensure node is connected
    if node in Node.list(:connected) do

      # Trap exits in case something goes wrong, store old value of flag
      prev = Process.flag(:trap_exit, true)

      # Start verify_local_worker function on remote node, receive result
      pid = Node.spawn_link(node, __MODULE__, :verify_local_worker, [self()])
      res = receive do
        bool when is_boolean(bool) -> bool
        {:EXIT, _, {:undef, _}} -> :invalid
      end

      # Shut down process and catch exit signal
      if res do
        Process.exit(pid, :normal)
        receive do {:EXIT, _, :normal} -> nil end
      end

      # Restore old state of flags and return
      Process.flag(:trap_exit, prev)
      res
    else
      :not_connected
    end
  end

  def verify_local_worker(sender) do
    send(sender, !is_nil(GenServer.whereis(__MODULE__)))
  end

  # ------ #
  # Server #
  # ------ #

  def init(_) do
    {:ok, []}
  end

  def handle_call({:add_master, master}, _from, masters) do
    if master in masters do
      {:reply, :already_connected, masters}
    else
      Logger.info "Registered new master: #{master}"
      {:reply, :ok, [master | masters]}
    end
  end

  def handle_cast({:remove_master, master}, masters) do
    Logger.info "Removing master: #{master}"
    {:noreply, List.delete(masters, master)}
  end
end
