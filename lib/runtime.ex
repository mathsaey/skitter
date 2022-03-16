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
    WorkflowManager,
    WorkerSupervisor,
    ComponentWorkerSupervisor,
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

  @doc """
  Get the name of the workflow node based on a context.

  This can only be executed on a runtime in `:master` or `:local` mode, as the information
  required to link a node to a context is only stored on the master runtime.
  """
  @spec node_name_for_context(Strategy.context()) :: Workflow.name()
  def node_name_for_context(%Strategy.Context{_skr: {ref, idx}}) do
    ComponentStore.get(:wf_node_names, ref, idx)
  end

  @doc """
  Get the workflow node based on a context

  The workflow node will always be a component node.

  This can only be executed on a runtime in `:master` or `:local` mode, as the information
  required to link a node to a context is only stored on the master runtime.
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

    # Store information to extract workflow information from the context
    ConstantStore.put(nodes, :wf_nodes, ref)
    nodes |> Map.keys() |> ComponentStore.put(:wf_node_names, ref)

    # Create supervisors on all workers for every component in the workflow
    Remote.on_all_workers(WorkflowWorkerSupervisor, :spawn_local_workflow, [ref, map_size(nodes)])

    # Store deployment information and links on all nodes
    deploy_components(nodes, ref)
    expand_links(nodes, ref)

    # Create manager
    WorkflowManagerSupervisor.add_manager(ref)
    notify_workers(nodes, ref)

    Telemetry.emit([:runtime, :deploy], %{}, %{ref: ref})
    ref
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

  # We notify components to finish deploying in reverse topological order.
  # This avoids race conditions where components can send data to other components which did not
  # finish deploying yet.
  defp notify_workers(_, ref) do
    ref
    |> topological_indices()
    |> Enum.reverse()
    |> Enum.each(fn idx ->
      Remote.on_all_workers(WorkerSupervisor, :all_children, [ref, idx, &Worker.deploy_complete/1])
    end)
  end

  @doc "Stop the workflow with reference `ref`."
  @spec stop(ref()) :: :ok
  def stop(ref) do
    WorkflowManager.stop(ref)

    # TODO: stop hook if introduced
    stop_workers(ref)

    Remote.on_all_workers(WorkflowWorkerSupervisor, :stop_local_workflow, [ref])
    remove_constants(ref)
    :ok
  end

  defp stop_workers(ref) do
    ref
    |> topological_indices()
    |> Enum.each(fn idx ->
      Remote.on_all_workers(fn ->
        WorkerSupervisor.stop(ComponentStore.get(:local_supervisors, ref, idx))
      end)
    end)
  end

  defp remove_constants(ref) do
    [:manager, :wf_nodes, :wf_node_names, :deployment, :links]
    |> Enum.each(&ConstantStore.remove(&1, ref))

    Remote.on_all_workers(fn ->
      [:component_worker_supervisors, :deployment, :links, :local_supervisors]
      |> Enum.each(&ConstantStore.remove(&1, ref))
    end)
  end

  defp topological_indices(ref) do
    ComponentStore.get_all(:links, ref)
    |> Enum.map(&Map.values/1)
    |> Enum.map(&Enum.concat/1)
    |> Enum.map(&Enum.map(&1, fn {%Strategy.Context{_skr: {_, i}}, _} -> i end))
    |> Enum.map(&MapSet.new/1)
    |> Enum.with_index()
    |> build_topological()
  end

  defp build_topological([]), do: []

  defp build_topological(lst) do
    {tail, rem} = Enum.split_with(lst, &(MapSet.size(elem(&1, 0)) == 0))

    tail = Enum.map(tail, &elem(&1, 1))
    rem = Enum.map(rem, fn {set, idx} -> {MapSet.difference(set, MapSet.new(tail)), idx} end)

    build_topological(rem) ++ tail
  end
end
