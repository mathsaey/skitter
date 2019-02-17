# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.NodesTest do
  use Skitter.Test.DistributedCase, mode: :master
  alias Skitter.Runtime.Nodes

  setup_all do
    nodes = Cluster.spawn_workers([:w1, :w2, :w3])
    [nodes: nodes]
  end

  setup %{nodes: nodes} do
    on_exit fn ->
      Enum.each(nodes, &Nodes.disconnect(&1))
    end
  end

  test "connecting", %{nodes: nodes} do
    Nodes.connect(nodes)
    Process.sleep(100)

    assert nodes == Nodes.all()
  end

  test "notifications", %{nodes: [w, _, _]} do
    b = Cluster.spawn_workers([:boom])

    Nodes.subscribe_join()
    Nodes.subscribe_leave()

    Nodes.connect(w)
    Nodes.connect(b)

    assert_receive {:node_join, w}
    assert_receive {:node_join, b}

    Nodes.disconnect(w)
    Cluster.kill_node(b)

    assert_receive {:node_leave, w, :removed}
    assert_receive {:node_leave, b, :disconnect}

    Nodes.unsubscribe_join()
    Nodes.unsubscribe_leave()

    Nodes.connect(w)
    Nodes.disconnect(w)

    send(self(), :flag)

    assert_receive :flag
  end

  test "tasks", %{nodes: nodes} do
    Nodes.connect(nodes)
    Process.sleep(100)

    assert Nodes.on_all(String, :to_integer, ["42"]) == [42, 42, 42]
    assert Nodes.on(hd(nodes), String, :to_integer, ["42"]) == 42
    assert Nodes.on_transient(String, :to_integer, ["42"]) == 42
    assert Nodes.on_permanent(String, :to_integer, ["42"]) == 42
  end
end
