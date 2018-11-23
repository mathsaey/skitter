# Copyright 2018, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Worker.DynamicWorkflowSupervisor do
  @moduledoc false
  use DynamicSupervisor

  def start_link(_) do
    DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def load_workflow(node, workflow) do
    spec = {Skitter.Runtime.Local.WorkflowSupervisor, workflow}
    DynamicSupervisor.start_child({__MODULE__, node}, spec)
  end

  def each_load_workflow(nodes, workflow) do
    Enum.map(nodes, fn node -> load_workflow(node, workflow) end)
  end
end
