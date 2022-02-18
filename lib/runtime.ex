# Copyright 2018 - 2022, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime do
  @moduledoc """
  Interface to the skitter runtime system.
  """
  alias Skitter.{Config, Remote, Workflow, Component, Strategy}

  alias Skitter.Runtime.{
    Worker,
    ConstantStore,
    ComponentStore,
    WorkerSupervisor,
    WorkflowWorkerSupervisor,
    WorkflowManagerSupervisor
  }

  require ComponentStore
  require ConstantStore
  use Skitter.Telemetry

  @typedoc "Reference to a deployed workflow."
  @type ref :: reference()

  @doc """
  Get the current runtime mode.

  This function returns the mode of the current runtime. The available modes and their goal are
  documented in the [configuration documentation](configuration.html#modes). This function may
  also return `:test`, which is only used for testing.
  """
  @spec mode :: :worker | :master | :local | :test
  def mode, do: Config.get(:mode, :local)

  @doc """
  Get the workflow for a reference or context.

  The workflow will not have any in or out ports and only contain component nodes, since
  `deploy/1` flattens workflows before it deploys them.
  """
  @spec get_workflow(ref() | Strategy.context()) :: Workflow.t()
  def get_workflow(r) when is_reference(r), do: %Workflow{nodes: ConstantStore.get(:wf_nodes, r)}
  def get_workflow(%Strategy.Context{_skr: {ref, _}}), do: get_workflow(ref)

  @doc "Get the name of the workflow node based on a context."
  @spec node_name_for_context(Strategy.context()) :: Workflow.name()
  def node_name_for_context(%Strategy.Context{_skr: {ref, idx}}) do
    ComponentStore.get(:wf_node_name, ref, idx)
  end

  @doc """
  Get the workflow node based on a context

  The workflow node will always be a component node.
  """
  @spec node_for_context(Strategy.context()) :: Workflow.component()
  def node_for_context(context), do: get_workflow(context).nodes[node_name_for_context(context)]

  @doc """
  Deploy a workflow.

  Starts a Skitter application (i.e. a workflow) by deploying it over the cluster. Returns a
  reference to the deployed workflow.
  """
  @spec deploy(Workflow.t()) :: ref()
  def deploy(workflow) do
    ref = make_ref()
    nodes = Workflow.flatten(workflow).nodes

    store_nodes(nodes, ref)
    store_node_names(nodes, ref)
    create_worker_supervisors(nodes, ref)
    deploy_components(nodes, ref)
    expand_links(nodes, ref)
    create_workflow_manager(nodes, ref)
    notify_workers(nodes, ref)

    ref
  end

  defp store_nodes(nodes, ref), do: ConstantStore.put_everywhere(nodes, :wf_nodes, ref)

  defp store_node_names(nodes, ref) do
    nodes |> Map.keys() |> ComponentStore.put_everywhere(:wf_node_name, ref)
  end

  # Create a supervisor on every node for each component in the workflow
  defp create_worker_supervisors(nodes, ref) do
    Remote.on_all_workers(WorkflowWorkerSupervisor, :spawn_local_workflow, [ref, map_size(nodes)])
  end

  # Deploy all components
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

      Telemetry.wrap [:hook, :deploy], %{context: context} do
        comp.strategy.deploy(context)
      end
    end)
    |> ComponentStore.put_everywhere(:deployment, ref)
  end

  # Lookup link destinations and create contexts in advance to avoid doing this at runtime.
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

    nodes
    |> Enum.map(fn {_, comp} ->
      Map.new(comp.links, fn {out_port, destinations} ->
        {out_port,
         Enum.map(destinations, fn {name, in_port} ->
           context = lookup[name]
           {context, Component.in_port_to_index(context.component, in_port)}
         end)}
      end)
    end)
    |> ComponentStore.put_everywhere(:links, ref)
  end

  defp create_workflow_manager(_, ref) do
    {:ok, pid} = WorkflowManagerSupervisor.add_manager(ref)
    ConstantStore.put_everywhere(pid, :manager, ref)
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
