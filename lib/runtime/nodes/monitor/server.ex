# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Nodes.Monitor.Server do
  @moduledoc false

  require Logger
  use GenServer, restart: :transient

  alias Skitter.Runtime.Nodes.Notifier

  def start_link(node) do
    GenServer.start_link(__MODULE__, node)
  end

  @impl true
  def init(node) do
    Process.monitor({Skitter.Runtime.Worker.Supervisor, node})
    setup_logger(node)
    {:ok, node}
  end

  defp setup_logger(node) do
    Logger.metadata(node: node)
    Logger.configure_backend(:console, metadata: [:node])
  end

  @impl true
  def handle_info({:DOWN, _, :process, _, :normal}, node) do
    Logger.info "Normal exit of monitored Skitter Worker"
    notify_and_halt(node, :normal)
  end

  @impl true
  def handle_info({:DOWN, _, :process, _, reason}, node) do
    Logger.warn "Skitter worker failed with #{reason}"
    notify_and_halt(node, reason)
  end

  defp notify_and_halt(node, reason) do
    Notifier.notify_leave(node, reason)
    {:stop, :normal, node}
  end
end
