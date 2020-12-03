# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Mode.Master.Manager do
  @moduledoc false
  use GenServer, restart: :transient

  alias Skitter.Remote
  alias Skitter.Runtime.WorkflowStore
  alias Skitter.Mode.Master.{WorkerConnection, ManagerSupervisor}

  defstruct [:ref, :wf]

  def create(wf), do: DynamicSupervisor.start_child(ManagerSupervisor, {__MODULE__, wf})

  def start_link(workflow) do
    GenServer.start_link(__MODULE__, workflow)
  end

  @impl true
  def init(workflow) do
    ref = WorkflowStore.put(workflow)
    :ok = WorkerConnection.subscribe_up()

    WorkerConnection.on_all(WorkflowStore, :put, [workflow, ref])
    |> Enum.all?(&(&1 == :ok))
    |> if(do: {:ok, %__MODULE__{ref: ref, wf: workflow}}, else: {:stop, :remote_put_failure})
  end

  @impl true
  def handle_info({:worker_up, worker}, s) do
    case Remote.on(worker, WorkflowStore, :put, [s.wf, s.ref]) do
      :ok -> {:noreply, s}
      _ -> {:stop, :remote_put_failure}
    end
  end
end
