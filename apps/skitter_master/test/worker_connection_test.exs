# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Master.WorkerConnectionTest do
  alias Skitter.Remote
  alias Skitter.Master.WorkerConnection

  use Skitter.Remote.Test.Case,
    mode: :master,
    handlers: [worker: WorkerConnection.Handler],
    remote_opts: [
      mode: :worker,
      handlers: [master: Remote.Test.AcceptHandler]
    ]

  describe "connecting" do
    @tag remote: [first: {[], [mode: :bad_mode]}, second: [], third: {[], [mode: :bad_mode]}]
    test "handles multiple connections", %{first: first, second: second, third: third} do
      assert WorkerConnection.connect([first, second, third]) ==
               {:error, [{first, :mode_mismatch}, {third, :mode_mismatch}]}

      assert second in WorkerConnection.all()
      assert WorkerConnection.connected?(second)
    end

    @tag remote: [worker: []]
    test "to a single node", %{worker: worker} do
      assert WorkerConnection.connect(worker) == :ok
      assert WorkerConnection.connected?(worker)
      assert worker in WorkerConnection.all()
    end

    @tag remote: [remote: {[], [mode: :not_worker]}]
    test "rejects non-workers", %{remote: remote} do
      assert WorkerConnection.connect(remote) == {:error, [{remote, :mode_mismatch}]}
      assert not WorkerConnection.connected?(remote)
      assert remote not in WorkerConnection.all()
    end

    @tag remote: [worker: []]
    test "removes after failure", %{worker: worker} do
      handler = Remote.Handler.get_pid(:worker)
      assert WorkerConnection.connect(worker) == :ok
      Cluster.kill_node(worker)

      # wait for handler to finish
      :sys.get_state(handler)
      assert worker not in WorkerConnection.all()
      assert not WorkerConnection.connected?(worker)
    end
  end

  describe "remote code execution" do
    @tag remote: [worker1: [], worker2: [], worker3: []]
    test "using module func arity", %{worker1: worker1, worker2: worker2, worker3: worker3} do
      :ok = WorkerConnection.connect([worker1, worker2, worker3])
      res = WorkerConnection.on_all(Node, :self, [])

      # Order depends on connection order, so cannot rely on it for test
      assert worker1 in res
      assert worker2 in res
      assert worker3 in res
    end

    @tag remote: [worker1: [], worker2: [], worker3: []]
    test "using closure", %{worker1: worker1, worker2: worker2, worker3: worker3} do
      :ok = WorkerConnection.connect([worker1, worker2, worker3])
      res = WorkerConnection.on_all(&Node.self/0)

      # Order depends on connection order, so cannot rely on it for test
      assert worker1 in res
      assert worker2 in res
      assert worker3 in res
    end
  end

  @tag remote: [worker1: [], worker2: []]
  test "notifications", %{worker1: worker1, worker2: worker2} do
    WorkerConnection.subscribe_up()
    WorkerConnection.subscribe_down()

    WorkerConnection.connect(worker1)
    assert_receive {:worker_up, ^worker1}
    Cluster.kill_node(worker1)
    assert_receive {:worker_down, ^worker1}

    WorkerConnection.unsubscribe_up()
    WorkerConnection.unsubscribe_down()

    WorkerConnection.connect(worker2)
    refute_received {:worker_up, ^worker2}
    Cluster.kill_node(worker2)
    refute_received {:worker_down, ^worker2}
  end
end
