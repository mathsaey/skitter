# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Workflow.Loader do
  @moduledoc false
  @supname Skitter.TaskSupervisor

  alias Skitter.Workflow
  alias Skitter.Runtime.Nodes
  alias Skitter.Runtime.Workflow.Store
  alias Skitter.Runtime.Workflow.Instance

  # TODO: Make it possible to load a workflow on a newly added node

  def load(workflow) do
    ref = make_ref()
    val = %{workflow | instances: load_instances(workflow)}
    res = Nodes.on_all(Store, :put, [ref, val])
    true = Enum.all?(res, &(&1 == hd(res)))
    {:ok, hd(res)}
  end

  def load_instances(workflow) do
    workflow
    |> Workflow.get_instances()
    |> Enum.map(&Task.Supervisor.async(@supname, __MODULE__, :load_inst, [&1]))
    |> Enum.map(&Task.await(&1))
    |> Map.new()
  end

  def load_inst({id, {comp, init, links}}) do
    {:ok, ref} = Skitter.Runtime.Component.load(comp, init)
    {id, %Instance{ref: ref, comp: comp, links: links}}
  end
end
