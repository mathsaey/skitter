# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Node.Master.WorkerConnectionTest do
  alias Skitter.Remote
  alias Skitter.Node.Master.WorkerConnection

  use Skitter.Remote.Test.Case,
    mode: :master,
    handlers: [worker: WorkerConnection.Handler],
    remote_config: [mode: :worker]

  setup do
    start_supervised!(WorkerConnection.Notifier)
    :ok
  end

  describe "connecting" do
    @tag remote: [
           first: [config: [mode: :none], start_on_remote: [mode: :wrong_mode]],
           second: [],
           third: [config: [mode: :none], start_on_remote: [mode: :wrong_mode]]
         ]
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

    @tag remote: [remote: [config: [mode: :none], start_on_remote: [mode: :not_worker]]]
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
