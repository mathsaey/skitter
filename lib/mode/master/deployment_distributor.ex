# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Mode.Master.DeploymentDistributor do
  @moduledoc false

  use GenServer
  require Logger

  alias Skitter.Remote
  alias Skitter.Runtime.DeploymentStore
  alias Skitter.Mode.Master.WorkerConnection

  def start_link(_), do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

  @impl true
  def init(_) do
    :ok = WorkerConnection.subscribe_up()
    {:ok, nil}
  end

  @impl true
  def handle_cast({:add, ref}, state) do
    val = DeploymentStore.get(ref)

    succes? =
      WorkerConnection.on_all(DeploymentStore, :add, [ref, val]) |> Enum.all?(&(&1 == :ok))

    unless succes?, do: Logger.error("Could not distribute deployment #{ref} to all nodes")

    {:noreply, state}
  end

  def handle_cast({:del, ref}, state) do
    succes? =
      WorkerConnection.on_all(DeploymentStore, :del, [ref])
      |> Enum.all?(&(&1 == :ok))

    unless succes?, do: Logger.error("Could not delete deployment #{ref} on all nodes")

    {:noreply, state}
  end

  @impl true
  def handle_info({:worker_up, worker}, state) do
    Enum.each(
      DeploymentStore.all(),
      fn {k, v} -> Remote.on(worker, DeploymentStore, :add, [k, v]) end
    )

    {:noreply, state}
  end
end
