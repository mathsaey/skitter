# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Master.WorkersTest do
  use Skitter.Runtime.Test.ClusterCase, async: false

  alias Skitter.Master.Workers

  alias Skitter.Runtime
  alias Skitter.Runtime.Test.DummyRemote

  alias Skitter.Worker.Master, as: RemoteServer

  describe "connecting" do
    test "discovery error are propagated" do
      assert Workers.connect(:"test@127.0.0.1") == {:error, ["test@127.0.0.1": :not_distributed]}
    end

    @tag distributed: [
           first: [{DummyRemote, :start, [RemoteServer, :skitter_worker, false]}],
           second: [{DummyRemote, :start, [RemoteServer, :skitter_worker, true]}],
           third: [{DummyRemote, :start, [RemoteServer, :skitter_worker, false]}]
         ]
    test "multiple errors", %{first: first, second: second, third: third} do
      assert Workers.connect([first, second, third]) ==
               {:error,
                [
                  {first, :rejected},
                  {third, :rejected}
                ]}

      assert second in Workers.all()
      assert Workers.connected?(second)
    end

    @tag distributed: [worker: [{DummyRemote, :start, [RemoteServer, :skitter_worker, true]}]]
    test "to a single node", %{worker: worker} do
      assert Workers.connect(worker) == :ok
      assert Workers.connected?(worker)
      assert worker in Workers.all()
    end

    @tag distributed: [master: [{DummyRemote, :start, [RemoteServer, :skitter_master, true]}]]
    test "rejects non-workers", %{master: master} do
      assert Workers.connect(master) == {:error, [{master, :mode_mismatch}]}
      assert not Workers.connected?(master)
      assert master not in Workers.all()
    end

    @tag distributed: [
           first: [{DummyRemote, :start, [RemoteServer, :skitter_worker, true]}],
           second: [{DummyRemote, :start, [RemoteServer, :skitter_worker, true]}]
         ]
    test "to multiple nodes", %{first: first, second: second} do
      assert Workers.connect([first, second]) == :ok

      assert Workers.connected?(first)
      assert Workers.connected?(second)
      assert first in Workers.all()
      assert second in Workers.all()
    end

    @tag distributed: [worker: [{DummyRemote, :start, [RemoteServer, :skitter_worker, true]}]]
    test "removes after failure", %{worker: worker} do
      assert Workers.connect(worker) == :ok
      Cluster.kill_node(worker)

      # wait for handler to finish
      :sys.get_state(Workers)
      assert worker not in Workers.all()
      assert not Workers.connected?(worker)
    end
  end

  describe "accepting" do
    @tag distributed: [remote: [{Runtime, :publish, [:not_a_worker]}]]
    test "only accepts workers", %{remote: remote} do
      assert not Cluster.rpc(remote, GenServer, :call, [{Workers, Node.self()}, {:accept, remote}])
    end

    @tag distributed: [worker: [{Runtime, :publish, [:skitter_worker]}]]
    test "successfully", %{worker: worker} do
      assert Cluster.rpc(worker, GenServer, :call, [{Workers, Node.self()}, {:accept, worker}])
      assert Workers.connected?(worker)
      assert worker in Workers.all()
    end

    @tag distributed: [worker: [{Runtime, :publish, [:skitter_worker]}]]
    test "removes after failure", %{worker: worker} do
      assert Cluster.rpc(worker, GenServer, :call, [{Workers, Node.self()}, {:accept, worker}])
      Cluster.kill_node(worker)

      # wait for handler to finish
      :sys.get_state(Workers)
      assert worker not in Workers.all()
      assert not Workers.connected?(worker)
    end
  end

  describe "remote code execution" do
    @tag distributed: [worker: [{DummyRemote, :start, [RemoteServer, :skitter_worker, true]}]]
    test "on a single node", %{worker: worker} do
      assert Workers.on(worker, Node, :self, []) == worker
    end

    @tag distributed: [
           worker1: [{DummyRemote, :start, [RemoteServer, :skitter_worker, true]}],
           worker2: [{DummyRemote, :start, [RemoteServer, :skitter_worker, true]}],
           worker3: [{DummyRemote, :start, [RemoteServer, :skitter_worker, true]}]
         ]
    test "on all nodes", %{worker1: worker1, worker2: worker2, worker3: worker3} do
      Workers.connect([worker1, worker2, worker3])
      res = Workers.on_all(Node, :self, [])

      # Order depends on connection order, so cannot rely on it for test
      assert worker1 in res
      assert worker2 in res
      assert worker3 in res
    end
  end

  @tag distributed: [
         worker1: [{DummyRemote, :start, [RemoteServer, :skitter_worker, true]}],
         worker2: [{DummyRemote, :start, [RemoteServer, :skitter_worker, true]}]
       ]
  test "notifications", %{worker1: worker1, worker2: worker2} do
    Workers.subscribe_up()
    Workers.subscribe_down()

    Workers.connect(worker1)
    assert_receive {:worker_up, ^worker1}
    Cluster.kill_node(worker1)
    assert_receive {:worker_down, ^worker1}

    Workers.unsubscribe_up()
    Workers.unsubscribe_down()

    Workers.connect(worker2)
    refute_received {:worker_up, ^worker2}
    Cluster.kill_node(worker2)
    refute_received {:worker_down, ^worker2}
  end
end
