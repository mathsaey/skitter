# Copyright 2018 - 2021, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Deployer do
  @moduledoc false

  alias Skitter.Runtime.{
    ConstantStore,
    Registry,
    WorkflowManagerSupervisor,
    WorkflowWorkerSupervisor
  }

  alias Skitter.{Component, Workflow, Port, Strategy}

  def deploy(workflow) do
    ref = make_ref()
    lst = convert_workflow(workflow)

    store_supervisors(ref, length(lst))

    lst
    |> Enum.map(fn {_comp, links, _args} -> links end)
    |> ConstantStore.put_everywhere(:skitter_links, ref)

    lst
    |> Enum.with_index()
    |> Enum.map(fn {{comp, _links, args}, idx} -> {comp, args, idx} end)
    |> Enum.map(&deploy_component(&1, ref))
    |> ConstantStore.put_everywhere(:skitter_deployment, ref)

    {:ok, pid} = WorkflowManagerSupervisor.add_manager(ref)
    pid
  end

  defp deploy_component({comp, args, idx}, ref) do
    strategy = Component.strategy(comp)
    context = %Strategy.Context{strategy: strategy, component: comp, _skr: {ref, idx}}
    strategy.deploy(context, args)
  end

  defp store_supervisors(ref, components) do
    Registry.on_all(__MODULE__, :store_local_supervisors, [ref, components])
  end

  def store_local_supervisors(ref, components) do
    {:ok, pid} = WorkflowWorkerSupervisor.add_workflow(ref, components)

    pid
    |> Supervisor.which_children()
    |> Enum.map(fn {idx, pid, _, _} -> {idx, pid} end)
    |> Enum.sort_by(&elem(&1, 0))
    |> Enum.map(&elem(&1, 1))
    |> ConstantStore.put(:skitter_supervisors, ref)
  end

  # Workflow Conversion
  # -------------------

  @spec convert_workflow(Workflow.t()) ::
          [{Component.t(), [{Port.t(), [{non_neg_integer(), Port.t(), Component.t()}]}], any()}]
  defp convert_workflow(workflow) do
    lst =
      workflow
      |> Skitter.Workflow.flatten()
      |> Map.fetch!(:nodes)
      |> Enum.to_list()

    table = lookup_table(lst)

    lst
    |> Enum.map(&elem(&1, 1))
    |> Enum.map(&{&1.component, update_links(&1.links, table), &1.args})
  end

  defp lookup_table(lst) do
    lst
    |> Enum.with_index()
    |> Enum.map(fn {{name, comp}, idx} -> {name, {idx, comp.component}} end)
    |> Map.new()
  end

  defp update_links(lst, table) do
    Enum.map(lst, fn {out, dsts} ->
      dsts =
        Enum.map(dsts, fn {name, port} ->
          {idx, comp} = table[name]
          {idx, port, comp, Component.strategy(comp)}
        end)

      {out, dsts}
    end)
  end
end
