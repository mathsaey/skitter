# Copyright 2018, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Worker.WorkflowSupervisor do
  @moduledoc false
  use Supervisor

  def start_link(workflow) do
    Supervisor.start_link(__MODULE__, workflow)
  end

  def init(workflow) do
    children = [
      {Skitter.Runtime.Local.WorkflowReplicaSupervisor, workflow},
      Skitter.Runtime.Local.InstanceSupervisor
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
