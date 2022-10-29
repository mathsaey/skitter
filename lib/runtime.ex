# Copyright 2018 - 2022, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime do
  @moduledoc """
  Interface to the skitter runtime system.
  """
  alias Skitter.{Config, Remote, Workflow, Operation, Strategy}

  alias Skitter.Runtime.{
    Worker,
    ConstantStore,
    NodeStore,
    WorkflowManager,
    WorkerSupervisor,
    WorkflowWorkerSupervisor,
    WorkflowManagerSupervisor
  }

  use Skitter.Telemetry
  require ConstantStore
  require NodeStore

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

  The workflow will not have any in or out ports and only contain operation nodes, since
  `deploy/1` flattens workflows before it deploys them.
  """
  @spec get_workflow(ref() | Strategy.context()) :: Workflow.t()
  def get_workflow(r) when is_reference(r), do: %Workflow{nodes: ConstantStore.get(:wf_nodes, r)}
  def get_workflow(%Strategy.Context{_skr: {ref, _}}), do: get_workflow(ref)

  @doc """
  Get the name of the workflow node based on a context.
  """
  @spec node_name_for_context(Strategy.context()) :: Workflow.name()
  def node_name_for_context(%Strategy.Context{_skr: {ref, idx}}) do
    NodeStore.get(:wf_node_names, ref, idx)
  end

  @doc """
  Get the workflow node based on a context.

  The workflow node will always be an operation node.
  """
  @spec node_for_context(Strategy.context()) :: Workflow.operation_node()
  def node_for_context(context), do: get_workflow(context).nodes[node_name_for_context(context)]

  @doc """
  Get the reference based on a context.

  This can be used to link a telemetry event which contained a context to a deployed workflow.
  """
  @spec ref_for_context(Strategy.context()) :: ref()
  def ref_for_context(%Strategy.Context{_skr: {ref, _}}), do: ref
  def ref_for_context(%Strategy.Context{_skr: {:deploy, ref, _}}), do: ref

  @doc """
  Get a list with references to every spawned workflow.

  This function communicates with the master node when called from a worker runtime.
  """
  @spec spawned_workflows :: [ref()]
  def spawned_workflows do
    case mode() do
      :worker ->
        Remote.on(Remote.master(), WorkflowManagerSupervisor, :spawned_workflow_references, [])

      _ ->
        WorkflowManagerSupervisor.spawned_workflow_references()
    end
  end

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
    ConstantStore.put_everywhere(nodes, :wf_nodes, ref)
    nodes |> Map.keys() |> NodeStore.put_everywhere(:wf_node_names, ref)

    # Create supervisors on all workers for every node in the workflow
    Remote.on_all_workers(WorkflowWorkerSupervisor, :spawn_local_workflow, [ref, map_size(nodes)])

    # Store deployment information and links on all nodes
    deploy_nodes(nodes, ref)
    expand_links(nodes, ref)

    # Create manager
    WorkflowManagerSupervisor.add_manager(ref)
    notify_workers(nodes, ref)

    Telemetry.emit([:runtime, :deploy], %{}, %{ref: ref})
    ref
  end

  # Deploy all nodes
  defp deploy_nodes(nodes, ref) do
    nodes
    |> Enum.with_index()
    |> Enum.map(fn {{_, node}, i} ->
      context = %Strategy.Context{
        operation: node.operation,
        strategy: node.strategy,
        args: node.args,
        _skr: {:deploy, ref, i}
      }

      Telemetry.wrap [:hook, :deploy], %{context: context} do
        node.strategy.deploy(context)
      end
    end)
    |> NodeStore.put_everywhere(:deployment, ref)
  end

  # Lookup link destinations and create contexts in advance to avoid doing this at runtime.
  defp expand_links(nodes, ref) do
    lookup =
      nodes
      |> Enum.with_index()
      |> Map.new(fn {{name, node}, i} ->
        {name,
         %Strategy.Context{
           operation: node.operation,
           strategy: node.strategy,
           args: node.args,
           deployment: NodeStore.get(:deployment, ref, i),
           _skr: {ref, i}
         }}
      end)

    nodes
    |> Enum.map(fn {_, node} ->
      Map.new(node.links, fn {out_port, destinations} ->
        {out_port,
         Enum.map(destinations, fn {name, in_port} ->
           context = lookup[name]
           {context, Operation.in_port_to_index(context.operation, in_port)}
         end)}
      end)
    end)
    |> NodeStore.put_everywhere(:links, ref)
  end

  # We notify workers to finish deploying in reverse topological order of the application DAG.
  # This avoids race conditions where nodes can send data to other nodes which did not finish
  # deploying yet.
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
    Telemetry.emit([:runtime, :stop], %{}, %{ref: ref})

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
        WorkerSupervisor.stop(NodeStore.get(:local_supervisors, ref, idx))
      end)
    end)
  end

  defp remove_constants(ref) do
    [:manager, :wf_nodes, :wf_node_names, :deployment, :links]
    |> Enum.each(&ConstantStore.remove(&1, ref))

    Remote.on_all_workers(fn ->
      [
        :wf_nodes,
        :wf_node_names,
        :operation_worker_supervisors,
        :deployment,
        :links,
        :local_supervisors
      ]
      |> Enum.each(&ConstantStore.remove(&1, ref))
    end)
  end

  defp topological_indices(ref) do
    NodeStore.get_all(:links, ref)
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
