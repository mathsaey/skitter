# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Nodes.Monitor do
  @moduledoc false

  alias Skitter.Runtime.Nodes.Monitor.{Server, Supervisor}

  def start_monitor(node) do
    DynamicSupervisor.start_child(Supervisor, {Server, node})
  end

  def remove_monitor(node) do
    Supervisor
    |> DynamicSupervisor.which_children()
    |> Enum.each(
      fn {:undefined, pid, :worker, [Server]} ->
        GenServer.cast(pid, {:node_removed, node})
      end)
  end
end
