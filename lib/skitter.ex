# Copyright 2018 - 2022, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter do
  @moduledoc """
  Skitter framework DSLs and runtime interaction.

  This module serves as an entry point to access both the DSLs implemented by Skitter and to
  interact with the Skitter runtime system. The former is done by adding `use Skitter` to an
  Elixir file or module, while the latter is done by calling the functions defined in this module.

  ### Domain-specific languages

  Adding `use Skitter.DSL` to an Elixir file or module imports the following macros:
  - `Skitter.DSL.Operation.defoperation/3`
  - `Skitter.DSL.Strategy.defstrategy/3`
  - `Skitter.DSL.Workflow.workflow/2`

  Which can be used to define operations, strategies and workflows.

  ### Runtime interaction

  The Skitter runtime system is responsible for deploying workflows over a cluster and for
  interacting with running workflows. The `Skitter.Runtime` module offers an API to interact with
  the runtime system and the information it tracks. This module offers a shorthand to access the
  most commonly used functions of this API.
  """

  defmacro __using__(_opts) do
    quote do
      import Skitter.DSL.Operation, only: [defoperation: 3, defoperation: 2]
      import Skitter.DSL.Workflow, only: [workflow: 1, workflow: 2]
      import Skitter.DSL.Strategy, only: [defstrategy: 2, defstrategy: 3]
    end
  end

  @doc """
  Deploy a workflow over the cluster.

  Starts a Skitter application (i.e. a `t:Skitter.Workflow.t/0`) by deploying it over the cluster.
  The workflow is flattened (using `Skitter.Workflow.flatten/1`) before it is deployed. After
  deployment, this function returns a `t:Skitter.Runtime.ref/0`, which can be used by the
  functions in `Skitter.Runtime`, or to stop the workflow.
  """
  def deploy(workflow), do: Skitter.Runtime.deploy(workflow)

  @doc """
  Stop a deployed workflow with reference `ref`.
  """
  def stop(ref), do: Skitter.Runtime.stop(ref)
end
