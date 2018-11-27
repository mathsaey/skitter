# Copyright 2018, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Master.NodeMonitor do
  @moduledoc false

  require Logger

  use GenServer, restart: :transient

  # --- #
  # API #
  # --- #

  def start_link(node), do: GenServer.start_link(__MODULE__, node)

  def subscribe(server, pid), do: GenServer.cast(server, {:subscribe, pid})
  def unsubscribe(server, pid), do: GenServer.cast(server, {:unsubscribe, pid})

  # ------ #
  # Server #
  # ------ #

  def init(node) do
    setup_logger(node)
    Process.monitor({Skitter.Runtime.Worker, node})
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

  def handle_info({:DOWN, _, :process, _, :normal}, {node, subscribers}) do
    Logger.info "Normal exit of monitored Skitter Worker"
    Skitter.Runtime.Master.remove_node(node)
    notify(subscribers, node, :normal)
    {:stop, :normal, {node, subscribers}}
  end

  def handle_info({:DOWN, _, :process, _, reason}, {node, subscribers}) do
    Logger.warn "Skitter worker failed with #{reason}"
    Skitter.Runtime.Master.remove_node(node)
    notify(subscribers, node, reason)
    {:stop, :normal, {node, subscribers}}
  end

  def handle_info(msg, {node, subscribers}) do
    Logger.debug "Received abnormal message: #{inspect msg}"
    {:noreply, {node, subscribers}}
  end

  defp notify(pids, node, reason) when is_list(pids) do
    Enum.each(pids, &notify(&1, node, reason))
  end

  defp notify(pid, node, reason), do: send(pid, {:node_down, node, reason})
end
