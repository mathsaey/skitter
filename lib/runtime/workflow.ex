# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Workflow do
  @moduledoc false
  alias __MODULE__.{Node, Store, Replica}

  alias Skitter.Workflow
  alias Skitter.Runtime.Nodes
  alias Skitter.Runtime.Spawner
  alias Skitter.Task.Supervisor, as: STS

  defstruct [:workflow, :instances, :links]

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
    links = Workflow.get_links(workflow)
    instances = load_instances(workflow)
    val = %__MODULE__{links: links, instances: instances, workflow: workflow}
    res = Nodes.on_all(Store, :put, [ref, val])
    true = Enum.all?(res, &(&1 == hd(res)))
    {:ok, hd(res)}
  end

  defp load_instances(workflow) do
    workflow
    |> Workflow.get_instances()
    |> Enum.map(&Task.Supervisor.async(STS, __MODULE__, :load_instance, [&1]))
    |> Enum.map(&Task.await(&1))
    |> Map.new()
  end

  def load_instance({id, {comp, init}}) do
    arity = Skitter.Component.arity(comp)
    in_ports = Skitter.Component.in_ports(comp)
    {:ok, ref} = Skitter.Runtime.Component.load(comp, init)
    {id, %Node{ref: ref, in_ports: in_ports, arity: arity}}
  end

  @doc """
  Spawn a replica to react to incoming data
  """
  def react(ref, args) do
    node = Nodes.select_transient()
    Spawner.spawn_async(node, Replica, {ref, args})
  end
end
