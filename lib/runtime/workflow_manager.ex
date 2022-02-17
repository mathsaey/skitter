# Copyright 2018 - 2022, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.WorkflowManager do
  @moduledoc """
  Workflow monitor

  This module defines a genserver which monitors a deployed workflow. It is responsible for
  ensuring the state of the deployed workflow is available when new workers are added to the
  cluster.
  """
  use GenServer

  alias Skitter.{Runtime, Remote}
  alias Skitter.Mode.Master.WorkerConnection
  alias Skitter.Runtime.{ComponentStore, WorkflowWorkerSupervisor}

  def start_link(args), do: GenServer.start_link(__MODULE__, args)

  def init(ref) do
    unless Runtime.mode() == :local, do: WorkerConnection.subscribe_up()
    {:ok, ref}
  end

  def handle_info({:worker_up, node, _}, ref) do
    links = ComponentStore.get_all(:skitter_links, ref)
    deployment = ComponentStore.get_all(:skitter_deployment, ref)

    Remote.on(node, fn ->
      ComponentStore.put(links, :skitter_links, ref)
      ComponentStore.put(deployment, :skitter_deployment, ref)
      WorkflowWorkerSupervisor.spawn_local_workflow(ref, length(links))
    end)

    {:noreply, ref}
  end
end
