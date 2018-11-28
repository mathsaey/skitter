# Copyright 2018, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Master.Nodes.Monitor do
  @moduledoc false

  require Logger

  use GenServer, restart: :transient

  alias Skitter.Runtime.Master.Nodes.Registry

  # --- #
  # API #
  # --- #

  def start_link(node), do: GenServer.start_link(__MODULE__, node)

  def remove(server), do: GenServer.cast(server, :remove)

  def subscribe(server, pid), do: GenServer.cast(server, {:subscribe, pid})
  def unsubscribe(server, pid), do: GenServer.cast(server, {:unsubscribe, pid})

  # ------ #
  # Server #
  # ------ #

  def init(node) do
    setup_logger(node)
    Process.monitor({Skitter.Runtime.Worker, node})
    :ok = Registry.register(node, self())
    Logger.info("Registered new worker: #{node}")
    {:ok, {node, []}}
  end

  defp setup_logger(node) do
    Logger.metadata(node: node)
    Logger.configure_backend(:console, metadata: [:node])
  end

  def handle_cast({:subscribe, pid}, {node, subscribers}) do
    {:noreply, {node, [pid | subscribers]}}
  end

  def handle_cast({:unsubscribe, pid}, {node, subscribers}) do
    {:noreply, {node, List.delete(subscribers, pid)}}
  end

  def handle_cast(:remove, {node, subscribers}) do
    Logger.debug "Removing #{node}"
    cleanup(subscribers, node, :normal)
  end

  def handle_info({:DOWN, _, :process, _, :normal}, {node, subscribers}) do
    Logger.info "Normal exit of monitored Skitter Worker"
    cleanup(subscribers, node, :normal)
  end

  def handle_info({:DOWN, _, :process, _, reason}, {node, subscribers}) do
    Logger.warn "Skitter worker failed with #{reason}"
    cleanup(subscribers, node, reason)
  end

  def handle_info(msg, {node, subscribers}) do
    Logger.debug "Received abnormal message: #{inspect msg}"
    {:noreply, {node, subscribers}}
  end

  defp cleanup(subscribers, node, reason) do
    Registry.unregister(node)
    notify(subscribers, node, reason)
    {:stop, :normal, {node, subscribers}}
  end

  defp notify(pids, node, reason) when is_list(pids) do
    Enum.each(pids, &notify(&1, node, reason))
  end

  defp notify(pid, node, reason), do: send(pid, {:node_down, node, reason})
end
