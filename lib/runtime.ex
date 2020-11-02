# Copyright 2018, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime do
  @moduledoc """
  Interface to Skitter's runtime system.
  """

  @doc """
  Deploy a workflow over the cluster.

  This function accepts a workflow name (defined with `Skitter.Workflow.DSL.workflow/3`) and
  distributes it over the cluster. `{:ok, instance}` is returned if the deployment was successful.
  """
  def load_workflow(workflow) do
    case Skitter.Runtime.Nodes.all() do
      [] -> {:error, :no_workers}
      _ -> Skitter.Runtime.Instance.create(workflow)
    end
  end

  @doc """
  Send data to a workflow instance.

  This function accepts a workflow instance (created by `load_workflow/1`) and a keyword list with
  arguments for the workflow. In this list, every key represents an in_port, while the value
  represents the data sent to the in port. Note that a value _must_ be provided for each in port.

  For instance, if you have instantiated a workflow with two in ports: `foo` and `bar` you can
  send data to this workflow as follows:

  ```
  react(instance, foo: "hello", bar: "world")
  ```
  """
  def react(wf, args) do
    Skitter.Runtime.Instance.react(wf, args)
  end
end
