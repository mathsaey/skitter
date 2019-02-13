# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Workflow do
  @moduledoc false
  alias __MODULE__.{Node, Store, Replica}

  alias Skitter.Runtime.Nodes
  alias Skitter.Runtime.Spawner
  alias Skitter.Task.Supervisor, as: STS

  # TODO: Make it possible to unload a workflow

  @doc """
  The children to be spawned for each loaded instance.
  """
  def child_specs(_), do: []

  @doc """
  Prepare a workflow for running on the skitter runtime.
  """
  def load(workflow) do
    ref = make_ref()
    val = %{workflow | instances: load_instances(workflow)}
    res = Nodes.on_all(Store, :put, [ref, val])
    true = Enum.all?(res, &(&1 == hd(res)))
    {:ok, hd(res)}
  end

  defp load_instances(workflow) do
    workflow
    |> Skitter.Workflow.get_instances()
    |> Enum.map(&Task.Supervisor.async(STS, __MODULE__, :load_instance, [&1]))
    |> Enum.map(&Task.await(&1))
    |> Map.new()
  end

  def load_instance({id, {comp, init, links}}) do
    meta = comp.__skitter_metadata__()
    {:ok, ref} = Skitter.Runtime.Component.load(comp, init)
    {id, %Node{ref: ref, meta: meta, links: links}}
  end

  @doc """
  Spawn a replica to react to incoming data
  """
  def react(ref, args) do
    node = Nodes.select_transient()
    Spawner.spawn_async(node, Replica, {ref, args})
  end
end
