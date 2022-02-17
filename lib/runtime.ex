# Copyright 2018 - 2022, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime do
  @moduledoc """
  Interface to the skitter runtime system.
  """
  alias Skitter.{Config, Remote, Workflow, Component, Strategy, Port, Deployment}
  alias Skitter.Runtime.{
    Worker,
    ComponentStore,
    WorkerSupervisor,
    WorkflowWorkerSupervisor,
    WorkflowManagerSupervisor
  }

  require ComponentStore

  @doc """
  Get the current runtime mode.

  This function returns the mode of the current runtime. The available modes and their goal are
  documented in the [configuration documentation](configuration.html#modes). This function may
  also return `:test`, which is only used for testing.
  """
  @spec mode :: :worker | :master | :local | :test
  def mode, do: Config.get(:mode, :local)

  @doc """
  Deploy a workflow.

  Starts a Skitter application (i.e. a workflow) by deploying it over the cluster.
  """
  @spec deploy(Workflow.t()) :: reference()
  def deploy(workflow) do
    ref = make_ref()
    nodes = Workflow.flatten(workflow).nodes

    create_worker_supervisors(nodes, ref)
    deploy_components(nodes, ref) |> ComponentStore.put_everywhere(:deployment, ref)
    expand_links(nodes, ref) |> ComponentStore.put_everywhere(:links, ref)

    create_workflow_manager(nodes, ref)
    notify_workers(nodes, ref)

    ref
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

  # We notify components to finish deploying in reverse topological order.
  # This avoids race conditions where components can send data to other components which did not
  # finish deploying yet.
  defp notify_workers(_, ref) do
    ComponentStore.get_all(:links, ref)
    |> Enum.map(&Map.values/1)
    |> Enum.map(&Enum.concat/1)
    |> Enum.map(&Enum.map(&1, fn {%Strategy.Context{_skr: {_, i}}, _} -> i end))
    |> Enum.map(&MapSet.new/1)
    |> Enum.with_index()
    |> notify_reverse_topological(ref)
  end

  defp notify_reverse_topological([], _), do: :ok

  defp notify_reverse_topological(lst, ref) do
    {to_notify, remaining} = Enum.split_with(lst, &(MapSet.size(elem(&1, 0)) == 0))
    to_notify = MapSet.new(to_notify, &elem(&1, 1))

    Enum.each(to_notify, fn idx ->
      Remote.on_all_workers(WorkerSupervisor, :all_children, [ref, idx, &Worker.deploy_complete/1])
    end)

    remaining
    |> Enum.map(fn {set, idx} -> {MapSet.difference(set, to_notify), idx} end)
    |> notify_reverse_topological(ref)
  end
end
