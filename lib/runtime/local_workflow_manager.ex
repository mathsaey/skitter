# Copyright 2018, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.LocalWorkflowManager do
  @moduledoc false
  use DynamicSupervisor

  def start_link(workflow) do
    DynamicSupervisor.start_link(__MODULE__, workflow)
  end

  def init(workflow) do
    DynamicSupervisor.init(
      strategy: :one_for_one,
      extra_arguments: [workflow]
    )
  end

  def react(sup, tokens) do
    spec = {Skitter.Runtime.WorkflowReplica, tokens}
    DynamicSupervisor.start_child(sup, spec)
  end
end
