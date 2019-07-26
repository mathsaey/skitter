# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.NodesTest do
  use Skitter.Test.DistributedCase, mode: :master
  alias Skitter.Runtime.Nodes

  setup_all do
    [workers: Cluster.spawn_workers([:w1, :w2])]
  end

  setup %{workers: workers} do
    on_exit(fn ->
      Enum.each(workers, &Nodes.disconnect(&1))
    end)
  end

  test "connects at application start", %{workers: workers} do
    Cluster.load_with(mode: :master, worker_nodes: workers)
    assert workers == Nodes.all()
  end

  test "can connect to node after starting", %{workers: workers} do
    Cluster.load_with(mode: :master, worker_nodes: [])
    w = hd(workers)
    Nodes.connect(w)
    assert [w] == Nodes.all()
  end

  test "can disconnect", %{workers: workers} do
    Cluster.load_with(mode: :master, worker_nodes: [])
    w = hd(workers)
    Nodes.connect(w)
    assert [w] == Nodes.all()
    Nodes.disconnect(w)
    assert [] == Nodes.all()
  end
end
