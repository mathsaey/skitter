# Copyright 2018 - 2022, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0

defmodule Skitter.Runtime.ComponentWorkerSupervisor do
  @moduledoc """
  This supervisor manages the supervisors spawned for each component.

  ```
  + ----------------- +        + ------------------ +                         + --------- +
  | WorkflowWorkerSup | - n -> | ComponentWorkerSup | - for each component -> | WorkerSup |
  + ----------------- +        + ------------------ +                         + --------- +
  ```

  When a workflow is deployed, a `Skitter.Runtime.ComponentWorkerSupervisor` will be spawned. This
  supervisor will spawn a supervisor for each component instance in the workflow.
  """
  use Supervisor, restart: :temporary
  alias Skitter.Runtime.{WorkerSupervisor, ComponentStore}

  def start_link(args), do: Supervisor.start_link(__MODULE__, args)

  @impl true
  def init({_ref, components}) do
    0..(components - 1)
    |> Enum.map(&Supervisor.child_spec({WorkerSupervisor, &1}, id: &1))
    |> Supervisor.init(strategy: :one_for_one, max_restarts: 0)
  end

  @doc """
  Store the pids of the spawned WorkerSupervisors in order.

  The pid of a `Skitter.Runtime.WorkerSupervisor` is needed to spawn workers managed by this
  supervisor. Since workers can be spawned dynamically, we need to be able to find the appropriate
  supervisor for a workflow at runtime. This is done by storing the pids of all the
  WorkerSupervisors in the `Skitter.Runtime.ComponentStore`. The pids are stored as a tuple, so
  that the pid of the relevant supervisor can be found based on the index of a component.
  """
  def store_supervisors(pid, ref) do
    pid
    |> Supervisor.which_children()
    |> Enum.map(fn {idx, pid, _, _} -> {idx, pid} end)
    |> Enum.sort_by(&elem(&1, 0))
    |> Enum.map(&elem(&1, 1))
    |> ComponentStore.put(:local_supervisors, ref)
  end
end
