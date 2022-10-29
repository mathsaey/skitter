# Copyright 2018 - 2022, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0

defmodule Skitter.Runtime.WorkflowWorkerSupervisor do
  @moduledoc """
  This supervisor indirectly manages the workers of all deployed workflows.

  ```
  + --- +        + ----------------- +                                 + ------------- +
  | App | - 1 -> | WorkflowWorkerSup | - for each deployed workflow -> | NodeWorkerSup |
  + --- +        + ----------------- +                                 + ------------- +
  ```

  When a workflow is deployed, this supervisor will spawn a
  `Skitter.Runtime.NodeWorkerSupervisor`, which is responsible for managing all the workers
  spawned by the various strategies in the workflow.
  """
  use DynamicSupervisor
  alias Skitter.Runtime.{NodeWorkerSupervisor, ConstantStore}
  require ConstantStore

  def start_link(arg), do: DynamicSupervisor.start_link(__MODULE__, arg, name: __MODULE__)

  @impl true
  def init(_arg), do: DynamicSupervisor.init(strategy: :one_for_one)

  @doc """
  Spawn the required supervisors for deploying a workflow on this runtime.

  This function spawns a supervision tree under this supervisor which will manage the workers of
  the deployed workflow. The `pid`s of the `Skitter.Runtime.WorkerSupervisor`s will be stored in
  the `Skitter.Runtime.NodeStore` with the `:skitter_supervisors` key.

  The pid of the spawned `Skitter.Runtime.NodeWorkerSupervisor` will be stored in the
  `Skitter.Runtime.ConstantStore` with the `:skitter_node_worker_superivor` key.
  """
  def spawn_local_workflow(ref, nodes) do
    {:ok, pid} =
      DynamicSupervisor.start_child(
        __MODULE__,
        {NodeWorkerSupervisor, {ref, nodes}}
      )

    NodeWorkerSupervisor.store_supervisors(pid, ref)
    ConstantStore.put(pid, :node_worker_supervisor, ref)
  end

  @doc "Stop the local workers spawned for the workflow with reference `ref`."
  def stop_local_workflow(ref) do
    pid = ConstantStore.get(:node_worker_supervisor, ref)
    DynamicSupervisor.terminate_child(__MODULE__, pid)
  end
end
