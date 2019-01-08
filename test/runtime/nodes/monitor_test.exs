# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.NodeMonitorTest do
  use ExUnit.Case, asyc: false
  @moduletag :distributed

  alias Skitter.Test.Cluster
  alias Skitter.Runtime.Nodes.{Monitor, Registry}

  setup_all do
    Cluster.become_master()
    w = Cluster.spawn_worker(:w)
    [worker: w]
  end

  setup do
    start_supervised(Registry)
    {:ok, pid} = start_supervised(Monitor.Supervisor)
    [sup: pid]
  end

  test "if the supervisor can be started correctly", %{sup: sup} do
    assert Process.alive?(sup)
  end

  test "if monitors are started under a supervisor", %{sup: s, worker: w} do
    {:ok, pid} = Monitor.start_monitor(w)

    children = DynamicSupervisor.which_children(s)
    child = {:undefined, pid, :worker, [Monitor.Server]}
    assert child in children
  end

  test "subscribe" do
    w = Cluster.spawn_worker(:w1)
    Monitor.start_monitor(w)
    Monitor.subscribe(w, self())

    Cluster.kill_node(w)
    assert_receive {:node_down, w, :noconnection}
  end

  test "unsubscribe" do
    w = Cluster.spawn_worker(:w2)
    Monitor.start_monitor(w)

    Monitor.subscribe(w, self())
    Monitor.unsubscribe(w, self())

    Cluster.kill_node(w)
    send(self(), :flag)

    assert_received :flag
  end
end
