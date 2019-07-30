# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.NodesTest do
  use Skitter.Test.DistributedCase
  alias Skitter.Runtime.Nodes

  setup_all do
    [workers: Cluster.spawn_workers([:w1, :w2])]
  end

  setup %{workers: workers} do
    on_exit(fn ->
      Enum.each(workers, &Nodes.disconnect(&1))
    end)
  end

  describe "connect" do
    test "at application start", %{workers: workers} do
      load_with(worker_nodes: workers)
      assert workers == Nodes.all()
    end

    test "at runtime", %{workers: [w, _]} do
      load_with()
      Nodes.connect(w)
      assert [w] == Nodes.all()
    end

    test "when a new worker joins", %{workers: [w, _]} do
      load_with(automatic_connect: true)
      pid = GenServer.whereis(Skitter.Runtime.Nodes.Registry)
      send(pid, {:nodeup, w, []})
      Process.sleep 300

      assert Nodes.all() == [w]
    end

    test "to an already connected node", %{workers: workers = [w, _]} do
      load_with(worker_nodes: workers)
      assert Nodes.connect(w) == {:error, :already_connected}
      assert Nodes.all() == workers
    end

    test "and disconnect", %{workers: [w, _]} do
      load_with()
      Nodes.connect(w)
      assert [w] == Nodes.all()
      Nodes.disconnect(w)
      assert [] == Nodes.all()
    end
  end

  describe "subscribe" do
    test "join and leave events", %{workers: [w, _]} do
      load_with()

      Nodes.subscribe_all()
      Nodes.connect(w)

      assert_receive {:node_join, w}

      Nodes.disconnect(w)

      assert_receive {:node_leave, w, _}
    end

    test "leave reasons", %{workers: [w1, _]} do
      load_with()
      [w2] = Cluster.spawn_workers([:crash_me])

      Nodes.subscribe_leave()
      Nodes.connect(w1)
      Nodes.connect(w2)

      Nodes.disconnect(w1)
      Cluster.kill_node(w2)

      assert_receive {:node_leave, w1, :removed}
      assert_receive {:node_leave, w2, :disconnect}
    end

    test "unsubscribe", %{workers: [w1, w2]} do
      load_with()

      Nodes.subscribe_join()
      Nodes.connect(w1)

      assert_receive {:node_join, w1}

      Nodes.unsubscribe_join()
      Nodes.connect(w2)
      send(self(), :ok)

      assert (receive do
        any -> any
      end) == :ok

      Nodes.subscribe_leave()
      Nodes.disconnect(w1)

      assert_receive {:node_leave, w1, _}

      Nodes.unsubscribe_leave()
      Nodes.disconnect(w2)
      send(self(), :ok)

      assert (receive do
        any -> any
      end) == :ok

      Nodes.unsubscribe_all()
      Nodes.connect(w1)
      Nodes.disconnect(w1)

      send(self(), :ok)

      assert (receive do
        any -> any
      end) == :ok
    end
  end
end
