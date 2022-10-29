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
  use GenServer, restart: :transient

  alias Skitter.{Runtime, Remote}
  alias Skitter.Mode.Master.WorkerConnection
  alias Skitter.Runtime.{ConstantStore, NodeStore, WorkflowWorkerSupervisor}

  require ConstantStore

  def start_link(args), do: GenServer.start_link(__MODULE__, args)
  def stop(ref), do: GenServer.stop(ConstantStore.get(:manager, ref))
  def ref(pid), do: GenServer.call(pid, :ref)

  @impl true
  def init(ref) do
    unless Runtime.mode() == :local, do: WorkerConnection.subscribe_up()
    ConstantStore.put(self(), :manager, ref)
    {:ok, ref}
  end

  @impl true
  def handle_call(:ref, _, ref), do: {:reply, ref, ref}

  @impl true
  def handle_info({:worker_up, node, _}, ref) do
    nodes = ConstantStore.get(:wf_nodes, ref)
    names = NodeStore.get_all(:wf_node_names, ref)
    links = NodeStore.get_all(:links, ref)
    deployment = NodeStore.get_all(:deployment, ref)

    Remote.on(node, fn ->
      ConstantStore.put(nodes, :wf_nodes, ref)
      NodeStore.put(names, :wf_node_names, ref)
      NodeStore.put(links, :links, ref)
      NodeStore.put(deployment, :deployment, ref)
      WorkflowWorkerSupervisor.spawn_local_workflow(ref, length(links))
    end)

    {:noreply, ref}
  end
end
