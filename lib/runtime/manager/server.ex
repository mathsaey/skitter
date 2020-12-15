# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Manager.Server do
  @moduledoc false
  use GenServer, restart: :transient

  alias Skitter.{Context, Invocation}
  alias Skitter.Runtime.WorkflowStore

  defstruct [:wf_ref, :wf, :dep]

  def start_link(hook, workflow) do
    GenServer.start_link(__MODULE__, [hook, workflow])
  end

  @impl true
  def init([hook, workflow]) do
    state = store_workflow(workflow)
    :ok = if(hook, do: hook.(state.wf), else: :ok)
    {:ok, state}
  end

  @impl true
  def handle_cast({:data, records}, s = %__MODULE__{wf_ref: wf_ref, dep: dep_ref}) do
    Skitter.Runtime.send(
      %Context{deployment_ref: dep_ref, workflow_ref: wf_ref, component_id: nil, manager: self()},
      records,
      Invocation.new()
    )

    {:noreply, s}
  end

  @impl true
  def terminate(_, %__MODULE__{wf: workflow, wf_ref: wf_ref, dep: dep_ref}) do
    Skitter.Runtime.drop_deployment(workflow, dep_ref)
    WorkflowStore.del(wf_ref)
  end

  defp store_workflow(workflow) do
    wf_ref = WorkflowStore.put(workflow)
    dep_ref = Skitter.Runtime.deploy(workflow, wf_ref, self())

    %__MODULE__{wf: workflow, wf_ref: wf_ref, dep: dep_ref}
  end
end
