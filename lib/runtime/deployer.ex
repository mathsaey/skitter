# Copyright 2018 - 2021, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Deployer do
  @moduledoc false
  # This module is responsible for deploying a workflow over the cluster.
  # This is done in a few steps:
  #   - A reference is created which uniquely identifies the spawned workflow.
  #   - The workflow is converted in a compact, tuple-based format which allows constant time
  #   fetching of component instances.
  #   - A supervision tree is spawned on each runtime, a reference to each WorkerSupervisor is
  #   stored on each runtime for easy access.
  #   - Each component is deployed. The returned data is stored on every runtime (this is
  #   the deployment data). The same tuple-based format is used for constant-time access.
  #   - The context of each outgoing link is fetched and stored. This is done to enable this
  #   lookup at runtime to occur in constant time instead of logarithmic time.
  #   - The spawned workers are notified that the deployment is finished. This is done to ensure
  #   no workers start to emit data before deployment is complete.
  #   - A workflow manager is spawned and returned.

  alias Skitter.Runtime.{
    ConstantStore,
    WorkflowManagerSupervisor,
    WorkflowComponentSupervisor,
    WorkerSupervisor,
    Worker
  }

  require ConstantStore
  alias Skitter.{Component, Workflow, Port, Strategy, Remote}

  def deploy(workflow) do
    ref = make_ref()
    lst = convert_workflow(workflow)

    store_supervisors(ref, length(lst))

    lst
    |> Enum.with_index()
    |> Enum.map(fn {{comp, strat, _links, args}, idx} -> {comp, strat, args, idx} end)
    |> Enum.map(&deploy_component(&1, ref))
    |> ConstantStore.put_everywhere(:skitter_deployment, ref)

    lst
    |> Enum.map(fn {_comp, _strat, links, _args} ->
      links
      |> Enum.map(&expand_links(&1, ref))
      |> Map.new()
    end)
    |> ConstantStore.put_everywhere(:skitter_links, ref)

    notify_workers(ref)

    {:ok, pid} = WorkflowManagerSupervisor.add_manager(ref)
    pid
  end

  defp deploy_component({comp, strat, args, idx}, ref) do
    context = %Strategy.Context{
      component: comp,
      strategy: strat,
      args: args,
      _skr: {:deploy, ref, idx}
    }

    strat.deploy(context)
  end

  defp expand_links({port, lst}, ref), do: {port, Enum.map(lst, &expand_link(&1, ref))}

  defp expand_link({idx, port, comp, strat}, ref) do
    context = %Strategy.Context{
      component: comp,
      strategy: strat,
      deployment: ConstantStore.get(:skitter_deployment, ref, idx),
      _skr: {ref, idx}
    }

    {context, Component.in_port_to_index(comp, port)}
  end

  defp store_supervisors(ref, components) do
    Remote.on_all_workers(__MODULE__, :store_local_supervisors, [ref, components])
  end

  def store_local_supervisors(ref, components) do
    {:ok, pid} = WorkflowComponentSupervisor.add_workflow(ref, components)

    pid
    |> Supervisor.which_children()
    |> Enum.map(fn {idx, pid, _, _} -> {idx, pid} end)
    |> Enum.sort_by(&elem(&1, 0))
    |> Enum.map(&elem(&1, 1))
    |> ConstantStore.put(:skitter_supervisors, ref)
  end

  defp notify_workers(ref) do
    Remote.on_all_workers(__MODULE__, :notify_local_workers, [ref])
  end

  def notify_local_workers(ref) do
    ConstantStore.get_all(:skitter_supervisors, ref)
    |> Enum.flat_map(&WorkerSupervisor.children/1)
    |> Enum.each(&Worker.notify_deploy_complete/1)
  end

  # Workflow Conversion
  # -------------------

  @spec convert_workflow(Workflow.t()) ::
          [
            {
              Component.t(),
              Strategy.t(),
              [{Port.t(), [{non_neg_integer(), Port.t(), Component.t()}]}],
              any()
            }
          ]
  defp convert_workflow(workflow) do
    lst = workflow |> Skitter.Workflow.flatten() |> Map.fetch!(:nodes) |> Enum.to_list()
    table = lookup_table(lst)

    Enum.map(lst, fn {_, comp} ->
      {comp.component, comp.strategy, update_links(comp.links, table), comp.args}
    end)
  end

  defp lookup_table(lst) do
    lst
    |> Enum.with_index()
    |> Enum.map(fn {{name, comp}, idx} ->
      {name, {idx, comp.component, comp.strategy}}
    end)
    |> Map.new()
  end

  defp update_links(lst, table) do
    Enum.map(lst, fn {out, dsts} ->
      dsts =
        Enum.map(dsts, fn {name, port} ->
          {idx, comp, strat} = table[name]
          {idx, port, comp, strat}
        end)

      {out, dsts}
    end)
  end
end
