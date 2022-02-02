# Copyright 2018 - 2022, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime do
  @moduledoc """
  Interface to the skitter runtime system.
  """
  alias Skitter.{Remote, Workflow, Component, Strategy, Port, Deployment}
  alias Skitter.Runtime.{
    Worker,
    ComponentStore,
    WorkerSupervisor,
    WorkflowWorkerSupervisor,
    WorkflowManagerSupervisor
  }

  require ComponentStore

  @doc """
  Deploy a workflow.

  Starts a Skitter application (i.e. a workflow) by deploying it over the cluster.
  """
  @spec deploy(Workflow.t()) :: :ok
  def deploy(workflow) do
    ref = make_ref()
    nodes = Workflow.flatten(workflow).nodes

    create_worker_supervisors(nodes, ref)
    deploy_components(nodes, ref) |> ComponentStore.put_everywhere(:deployment, ref)
    expand_links(nodes, ref) |> ComponentStore.put_everywhere(:links, ref)

    create_workflow_manager(nodes, ref)
    notify_workers(nodes, ref)

    :ok
  end

  defp create_worker_supervisors(nodes, ref) do
    Remote.on_all_workers(WorkflowWorkerSupervisor, :spawn_local_workflow, [ref, map_size(nodes)])
  end

  @spec deploy_components(%{Workflow.name() => Workflow.component()}, reference()) ::
          [Deployment.data()]
  defp deploy_components(nodes, ref) do
    nodes
    |> Enum.with_index()
    |> Enum.map(fn {{_, comp}, i} ->
      context = %Strategy.Context{
        component: comp.component,
        strategy: comp.strategy,
        args: comp.args,
        _skr: {:deploy, ref, i}
      }

      comp.strategy.deploy(context)
    end)
  end

  @spec expand_links(%{Workflow.name() => Workflow.component()}, reference()) ::
          [%{Port.t() => [{Strategy.context(), Port.index()}]}]
  defp expand_links(nodes, ref) do
    lookup =
      nodes
      |> Enum.with_index()
      |> Map.new(fn {{name, comp}, i} ->
        {name,
         %Strategy.Context{
           component: comp.component,
           strategy: comp.strategy,
           args: comp.args,
           deployment: ComponentStore.get(:deployment, ref, i),
           _skr: {ref, i}
         }}
      end)

    Enum.map(nodes, fn {_, comp} ->
      Map.new(comp.links, fn {out_port, destinations} ->
        {out_port,
         Enum.map(destinations, fn {name, in_port} ->
           context = lookup[name]
           {context, Component.in_port_to_index(context.component, in_port)}
         end)}
      end)
    end)
  end

  defp create_workflow_manager(_, ref) do
    {:ok, _} = WorkflowManagerSupervisor.add_manager(ref)
  end

  defp notify_workers(_, ref) do
    Remote.on_all_workers(WorkerSupervisor, :on_all_children, [ref, &Worker.deploy_complete/1])
  end
end
