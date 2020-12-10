# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Manager do
  @moduledoc false
  use GenServer, restart: :transient

  alias Skitter.Runtime.{WorkflowStore, Manager.Supervisor}

  defstruct [:wf, :dep]

  def create(workflow) do
    {:ok, pid} = DynamicSupervisor.start_child(Supervisor, {__MODULE__, workflow})
    %Skitter.Proxy{pid: pid, name: workflow.name}
  end

  def start_link(hook, workflow) do
    GenServer.start_link(__MODULE__, [hook, workflow])
  end

  @impl true
  def init([hook, workflow]) do
    state = store_workflow(workflow)
    :ok = if(hook, do: hook.(state.wf), else: :ok)
    {:ok, state}
  end

  defp store_workflow(workflow) do
    wf_ref = WorkflowStore.put(workflow)
    dep_ref = Skitter.Runtime.deploy(workflow, wf_ref)

    %__MODULE__{wf: wf_ref, dep: dep_ref}
  end
end
