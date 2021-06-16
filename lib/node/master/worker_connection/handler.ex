# Copyright 2018 - 2021, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Node.Master.WorkerConnection.Handler do
  @moduledoc false
  require Logger

  use Skitter.Remote.Handler

  alias Skitter.Remote
  alias Skitter.Runtime.Registry
  alias Skitter.Node.Worker.Tags
  alias Skitter.Node.Master.WorkerConnection.Notifier

  @impl true
  def init do
    Registry.start_link()
    nil
  end

  @impl true
  def accept_connection(node, :worker, state) do
    if Registry.connected?(node) do
      {:error, :already_connected, state}
    else
      tags = Remote.on(node, &Tags.get/0)
      Logger.info("Connected to `#{node}` (#{tags})")
      Notifier.notify_up(node, tags)
      Registry.add(node, tags)
      {:ok, state}
    end
  end

  @impl true
  def remove_connection(node, state) do
    Logger.info("Disconnected from `#{node}`")
    Notifier.notify_down(node)
    Registry.remove(node)
    state
  end

  @impl true
  def remote_down(node, state) do
    Logger.info("Worker `#{node}` disconnected")
    Notifier.notify_down(node)
    Registry.remove(node)
    state
  end
end
