# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Nodes.Monitor do
  @moduledoc false

  alias Skitter.Runtime.Nodes.{Registry, Monitor.Server, Monitor.Supervisor}

  def start_monitor(node) do
    {:ok, pid} = DynamicSupervisor.start_child(Supervisor, {Server, node})
    Registry.update(node, monitor: pid)
    {:ok, pid}
  end

  def subscribe(node, pid), do: monitor_cast(node, {:subscribe, pid})
  def unsubscribe(node, pid), do: monitor_cast(node, {:unsubscribe, pid})

  defp monitor_cast(node, cast) do
    %Registry{monitor: m} = Registry.get(node)
    GenServer.cast(m, cast)
  end
end
