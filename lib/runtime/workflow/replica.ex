# Copyright 2018, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Workflow.Replica do
  @moduledoc false

  alias Skitter.Runtime.Workflow.Replica.{Server, Supervisor}

  @doc """
  Returns a `child_spec` for a supervisor that should supervise replicas.

  As the supervisor will dynamically add the workflow to the spawned replica,
  a workflow should be provided to this function.
  """
  def supervisor(workflow), do: {Supervisor, workflow}

  @doc """
  Spawn a GenServer which will manage a workflow replica under a supervisor.

  `supervisor` should be a supervisor spawned based on the `child_spec`
  returned by `supervisor/1`. `tokens` should contain a keyword list of tokens
  the supervisor should react to.

  Once initialized, the workflow replica will immediately start reacting.
  """
  def start_supervised(supervisor, tokens) do
    DynamicSupervisor.start_child(supervisor, {Server, tokens})
  end

  def add_token(replica, token, address) do
    GenServer.cast(replica, {:token, token, address})
  end

  def notify_react_finished(replica) do
    GenServer.cast(replica, :react_finished)
  end
end
