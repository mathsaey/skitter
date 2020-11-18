# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Worker.MasterConnectionTest do
  import ExUnit.CaptureLog

  alias Skitter.{Remote, Worker.MasterConnection}
  alias Skitter.Worker.MasterConnection

  use Skitter.Remote.Test.Case,
    mode: :worker,
    handlers: [master: Skitter.Worker.MasterConnection],
    remote_opts: [
      mode: :master,
      handlers: [worker: Remote.Test.AcceptHandler]
    ]

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

  @tag remote: [remote: {[], mode: :not_master}]
  test "connecting to a non-master", %{remote: remote} do
    assert MasterConnection.connect(remote) == {:error, :mode_mismatch}
  end

  @tag remote: [master: []]
  test "master failure detection", %{master: master} do
    handler = Remote.Dispatcher.get_handler(:master)
    assert MasterConnection.connect(master) == :ok

    assert capture_log(fn ->
             Cluster.kill_node(master)
             # Wait for failure handling to finish
             :sys.get_state(handler)
           end) =~ "Master `#{master}` disconnected"

    assert {_, nil} = :sys.get_state(handler)
  end
end
