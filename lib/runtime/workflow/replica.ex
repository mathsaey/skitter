# Copyright 2018, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Workflow.Replica do
  @moduledoc false

  alias Skitter.Runtime.Nodes
  alias Skitter.Runtime.Workflow.Replica.{Server, Supervisor}

  def supervisor(), do: Supervisor

  def react(ref, args) do
    node = Nodes.select_transient()
    {:ok, _} = DynamicSupervisor.start_child(
      {Supervisor, node}, {Server, {ref, args}}
    )
  end
end
