# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Mode.Local.Manager do
  @moduledoc false
  use GenServer, restart: :transient

  alias Skitter.Runtime.WorkflowStore
  alias Skitter.Mode.Local.ManagerSupervisor

  defstruct [:ref]

  def create(wf), do: DynamicSupervisor.start_child(ManagerSupervisor, {__MODULE__, wf})

  def start_link(workflow) do
    GenServer.start_link(__MODULE__, workflow)
  end

  @impl true
  def init(workflow) do
    ref = WorkflowStore.put(workflow)
    {:ok, %__MODULE__{ref: ref}}
  end
end
