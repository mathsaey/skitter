# Copyright 2018, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.NodeMonitor do
  @moduledoc false

  require Logger

  use GenServer, restart: :transient

  # --- #
  # API #
  # --- #

  def start_link(node) do
    GenServer.start_link(__MODULE__, node)
  end

  # ------ #
  # Server #
  # ------ #

  def init(node) do
    setup_logger(node)
    Process.monitor({Skitter.Runtime.Worker, node})
    {:ok, node}
  end

  defp setup_logger(node) do
    Logger.metadata(node: node)
    Logger.configure_backend(:console, metadata: [:node])
  end

  def handle_info({:DOWN, _ref, :process, _pid, :normal}, node) do
    Logger.info "Normal exit of monitored Skitter Worker"
    Skitter.Runtime.remove_node(node)
    {:stop, :normal, node}
  end

  def handle_info({:DOWN, _ref, :process, _pid, reason}, node) do
    Logger.warn "Skitter worker failed with #{reason}"
    Skitter.Runtime.remove_node(node)
    {:stop, :normal, node}
  end

  def handle_info(msg, node) do
    Logger.debug "Received abnormal message: #{inspect msg}"
    {:noreply, node}
  end
end
