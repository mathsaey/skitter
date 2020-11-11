# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Worker.MasterConnectionTest do
  use Skitter.Remote.Test.ClusterCase, restart: :skitter_worker, async: false
  import ExUnit.CaptureLog

  alias Skitter.Remote
  alias Skitter.Worker.MasterConnection

  @tag distributed: [master: [{Remote.Test.Handler, :setup, [:master]}]]
  test "connecting", %{master: master} do
    assert MasterConnection.connect(master) == :ok
  end

  @tag distributed: [
         first: [{Remote.Test.Handler, :setup, [:master]}],
         second: [{Remote.Test.Handler, :setup, [:master]}]
       ]
  test "attempting to establish two connections", %{first: first, second: second} do
    assert MasterConnection.connect(first) == :ok
    assert MasterConnection.connect(second) == {:error, :has_master}
  end

  @tag distributed: [master: [{Remote.Test.Handler, :setup, [:master]}]]
  test "attempting to establish two connections from the same master", %{master: master} do
    assert MasterConnection.connect(master) == :ok
    assert MasterConnection.connect(master) == {:error, :already_connected}
  end

  @tag distributed: [remote: [{Remote.Test.Handler, :setup, [:not_a_master]}]]
  test "connecting to a non-master", %{remote: remote} do
    assert MasterConnection.connect(remote) == {:error, :mode_mismatch}
  end

  @tag distributed: [master: [{Remote.Test.Handler, :setup, [:master]}]]
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
