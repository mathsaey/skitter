# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Mode.Master.WorkflowStoreDistributor.Server do
  @moduledoc false

  use GenServer, restart: :transient

  alias Skitter.Remote
  alias Skitter.Runtime.WorkflowStore
  alias Skitter.Mode.Master.WorkerConnection

  def start_link(ref), do: GenServer.start_link(__MODULE__, ref)

  @impl true
  def init(ref) do
    :ok = WorkerConnection.subscribe_up()
    wf = WorkflowStore.get(ref)

    WorkerConnection.on_all(WorkflowStore, :put, [wf, ref])
    |> Enum.all?(&(&1 == :ok))
    |> if(do: :ok, else: {:stop, :remote_put_failure})

    {:ok, {ref, wf}}
  end

  @impl true
  def handle_info({:worker_up, worker}, {ref, wf}) do
    case Remote.on(worker, WorkflowStore, :put, [wf, ref]) do
      :ok -> {:noreply, {ref, wf}}
      _ -> {:stop, :remote_put_failure}
    end
  end
end
