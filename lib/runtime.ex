# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime do
  @moduledoc false

  alias Skitter.{Context, Workflow}
  alias Skitter.Runtime.{DeploymentStore, Strategy, WorkflowStore}

  def deploy(%Workflow{nodes: nodes}, wf_ref, manager) do
    ref = make_ref()

    data =
      Enum.map(nodes, fn {name, {comp, args}} ->
        {
          name,
          Strategy.deploy(
            comp,
            %Context{
              deployment_ref: ref,
              workflow_ref: wf_ref,
              component_id: name,
              manager: manager
            },
            args
          )
        }
      end)
      |> Map.new()

    DeploymentStore.add(ref, data)
    ref
  end

  def send(ctx, tokens) do
    wf = WorkflowStore.get(ctx.workflow_ref)
    source = wf.links[ctx.component_id]

    for {port, value} <- tokens do
      for {dst_name, dst_port} <- source[port] || [] do
        case wf[dst_name] do
          {comp, _} -> Strategy.send(comp, %{ctx | component_id: dst_name}, value, dst_port, nil)
          nil -> :ok
        end
      end
    end
  end

  def drop_deployment(%Workflow{nodes: nodes}, dep_ref) do
    deployment = DeploymentStore.get(dep_ref)
    DeploymentStore.del(dep_ref)

    Enum.each(nodes, fn {name, {component, _}} ->
      Strategy.drop_deployment(component, deployment[name])
    end)
  end
end
