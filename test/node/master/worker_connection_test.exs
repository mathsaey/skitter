# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Node.Master.WorkerConnectionTest do
  alias Skitter.Remote

  alias Skitter.Runtime.Registry
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
           first: [config: [mode: :test], start_on_remote: [mode: :wrong_mode]],
           second: [],
           third: [config: [mode: :test], start_on_remote: [mode: :wrong_mode]]
         ]
    test "handles multiple connections", %{first: first, second: second, third: third} do
      assert WorkerConnection.connect([first, second, third]) ==
               {:error, [{first, :mode_mismatch}, {third, :mode_mismatch}]}

      assert second in Registry.all()
      assert Registry.connected?(second)
    end

    @tag remote: [worker: []]
    test "to a single node", %{worker: worker} do
      assert WorkerConnection.connect(worker) == :ok
      assert Registry.connected?(worker)
      assert worker in Registry.all()
    end

    @tag remote: [remote: [config: [mode: :test], start_on_remote: [mode: :not_worker]]]
    test "rejects non-workers", %{remote: remote} do
      assert WorkerConnection.connect(remote) == {:error, [{remote, :mode_mismatch}]}
      assert not Registry.connected?(remote)
      assert remote not in Registry.all()
    end

    @tag remote: [
           first: [config: [tags: [:a, :b]]],
           second: [config: [tags: [:b, :c]]]
         ]
    test "gets tags", %{first: first, second: second} do
      handler = Remote.Handler.get_pid(:worker)

      assert WorkerConnection.connect(first) == :ok
      assert WorkerConnection.connect(second) == :ok

      # wait for handler to finish
      :sys.get_state(handler)

      first_tags = Registry.tags(first)
      second_tags = Registry.tags(second)

      assert :a in first_tags
      assert :b in first_tags
      assert :b in second_tags
      assert :c in second_tags
    end

    @tag remote: [worker: []]
    test "removes after failure", %{worker: worker} do
      handler = Remote.Handler.get_pid(:worker)
      assert WorkerConnection.connect(worker) == :ok
      Cluster.kill_node(worker)

      # wait for handler to finish
      :sys.get_state(handler)
      assert worker not in Registry.all()
      assert not Registry.connected?(worker)
    end
  end

  @tag remote: [worker1: [config: [tags: [:a]]], worker2: []]
  test "notifications", %{worker1: worker1, worker2: worker2} do
    WorkerConnection.subscribe_up()
    WorkerConnection.subscribe_down()

    WorkerConnection.connect(worker1)
    assert_receive {:worker_up, ^worker1, [:a]}
    Cluster.kill_node(worker1)
    assert_receive {:worker_down, ^worker1}

    WorkerConnection.unsubscribe_up()
    WorkerConnection.unsubscribe_down()

    WorkerConnection.connect(worker2)
    refute_received {:worker_up, ^worker2, []}
    Cluster.kill_node(worker2)
    refute_received {:worker_down, ^worker2}
  end
end
