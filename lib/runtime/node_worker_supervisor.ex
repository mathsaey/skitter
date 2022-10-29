# Copyright 2018 - 2022, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0

defmodule Skitter.Runtime.NodeWorkerSupervisor do
  @moduledoc """
  This supervisor manages the supervisors spawned for each node.

  ```
  + ----------------- +        + ------------- +                     + --------- +
  | WorkflowWorkerSup | - n -> | NodeWorkerSup | - for each node --> | WorkerSup |
  + ----------------- +        + ------------- +                     + --------- +
  ```

  When a workflow is deployed, a `Skitter.Runtime.NodeWorkerSupervisor` will be spawned. This
  supervisor will spawn a supervisor for each node in the workflow.
  """
  use Supervisor, restart: :temporary
  alias Skitter.Runtime.{WorkerSupervisor, NodeStore}

  def start_link(args), do: Supervisor.start_link(__MODULE__, args)
  def stop_child(pid), do: DynamicSupervisor.terminate_child(__MODULE__, pid)

  @impl true
  def init({_ref, nodes}) do
    0..(nodes - 1)
    |> Enum.map(&Supervisor.child_spec({WorkerSupervisor, &1}, id: &1))
    |> Supervisor.init(strategy: :one_for_one, max_restarts: 0)
  end

  @doc """
  Store the pids of the spawned WorkerSupervisors in order.

  The pid of a `Skitter.Runtime.WorkerSupervisor` is needed to spawn workers managed by this
  supervisor. Since workers can be spawned dynamically, we need to be able to find the appropriate
  supervisor for a workflow at runtime. This is done by storing the pids of all the
  WorkerSupervisors in the `Skitter.Runtime.NodeStore`. The pids are stored as a tuple, so that
  the pid of the relevant supervisor can be found based on the index of a node.
  """
  def store_supervisors(pid, ref) do
    pid
    |> Supervisor.which_children()
    |> Enum.map(fn {idx, pid, _, _} -> {idx, pid} end)
    |> Enum.sort_by(&elem(&1, 0))
    |> Enum.map(&elem(&1, 1))
    |> NodeStore.put(:local_supervisors, ref)
  end
end
