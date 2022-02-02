# Copyright 2018 - 2022, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Mode.Worker.MasterConnectionTest do
  import ExUnit.CaptureLog

  alias Skitter.Remote
  alias Skitter.Mode.Worker.{MasterConnection, RegistryManager}

  use Skitter.Remote.Test.Case,
    mode: :worker,
    handlers: [master: MasterConnection],
    remote_config: [mode: :master]

  setup do
    start_supervised(RegistryManager)
    :ok
  end

  @tag remote: [master: []]
  test "connecting", %{master: master} do
    assert MasterConnection.connect(master) == :ok
  end

  @tag remote: [first: [], second: []]
  test "attempting to establish two connections", %{first: first, second: second} do
    assert MasterConnection.connect(first) == :ok
    assert MasterConnection.connect(second) == {:error, :has_master}
  end

  @tag remote: [master: []]
  test "attempting to establish two connections from the same master", %{master: master} do
    assert MasterConnection.connect(master) == :ok
    assert MasterConnection.connect(master) == {:error, :already_connected}
  end

  @tag remote: [remote: [config: [mode: :test], start_on_remote: [mode: :not_master]]]
  test "connecting to a non-master", %{remote: remote} do
    assert MasterConnection.connect(remote) == {:error, :mode_mismatch}
  end

  @tag remote: [master: []]
  test "master failure detection", %{master: master} do
    handler = Remote.Handler.get_pid(:master)
    assert MasterConnection.connect(master) == :ok

    assert capture_log(fn ->
             Cluster.kill_node(master)
             # Wait for failure handling to finish
             :sys.get_state(handler)
           end) =~ "Master `#{master}` disconnected"

    assert {_, nil} = :sys.get_state(handler)
  end

  @tag remote: [
         master: [],
         worker1: [config: [mode: :worker]],
         worker2: [config: [mode: :worker]]
       ]
  test "worker listing", %{master: master, worker1: worker1, worker2: worker2} do
    manager = GenServer.whereis(RegistryManager)
    Cluster.rpc(worker1, MasterConnection, :connect, [master])
    assert MasterConnection.connect(master) == :ok

    :sys.get_state(manager)
    assert Node.self() in Remote.workers()
    assert worker1 in Remote.workers()

    Cluster.rpc(worker2, MasterConnection, :connect, [master])
    # Give the changes some time to propagate
    Process.sleep(100)
    :sys.get_state(manager)
    assert worker2 in Remote.workers()

    Cluster.kill_node(worker1)
    Process.sleep(100)
    :sys.get_state(manager)
    assert worker1 not in Remote.workers()
  end
end
