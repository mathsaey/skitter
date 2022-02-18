# Copyright 2018 - 2022, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Mode.Master.WorkerConnection.Handler do
  @moduledoc false
  require Logger

  use Skitter.Telemetry
  use Skitter.Remote.Handler

  alias Skitter.{Config, ExitCodes}
  alias Skitter.Remote.{Registry, Tags}
  alias Skitter.Mode.Master.WorkerConnection.Notifier

  @impl true
  def init do
    Tags.start_link()
    Registry.start_link()
    Registry.add(Node.self(), :master)
    nil
  end

  @impl true
  def accept_connection(node, :worker, state) do
    if Registry.connected?(node) do
      {:error, :already_connected, state}
    else
      tags = Tags.remote(node)
      Telemetry.emit([:remote, :up, :worker], %{}, %{remote: node, tags: tags})
      Logger.info("Connected to `#{node}`, tags: #{inspect(tags)}")
      Notifier.notify_up(node, tags)
      Registry.add(node, :worker)
      Tags.add(node, tags)
      {:ok, state}
    end
  end

  @impl true
  def remove_connection(node, state) do
    Telemetry.emit([:remote, :down, :worker], %{}, %{remote: node, reason: :remove})
    Logger.info("Disconnected from `#{node}`")
    Notifier.notify_down(node)
    Registry.remove(node)
    Tags.remove(node)
    state
  end

  @impl true
  def remote_down(node, state) do
    Telemetry.emit([:remote, :down, :worker], %{}, %{remote: node, reason: :down})
    Logger.info("Worker `#{node}` disconnected")
    Notifier.notify_down(node)
    Registry.remove(node)
    Tags.remove(node)

    if Config.get(:shutdown_with_workers, false) do
      Logger.notice("Lost connection to worker, shutting down...")
      System.stop(ExitCodes.remote_shutdown())
    end

    state
  end
end
