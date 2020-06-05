# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Worker.MasterConnectionTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureLog

  alias Skitter.Runtime.Test.Cluster
  alias Skitter.Worker.Test.DummyMaster

  alias Skitter.Runtime
  alias Skitter.Worker.MasterConnection

  test "discovery errors are propagated" do
      Node.stop()
    assert MasterConnection.connect(:"test@127.0.0.1") == {:error, :not_distributed}
  end

  @tag :distributed
  test "connecting to a non-master fails" do
    remote = Cluster.spawn_node(:not_master, :skitter_runtime, [])
    Cluster.rpc(remote, Runtime, :publish, [:not_master])
    assert MasterConnection.connect(remote) == {:error, :not_master}
  end

  @tag :distributed
  test "connect to master, detect failure" do
    remote = Cluster.spawn_node(:master, :skitter_runtime, [])
    Cluster.rpc(remote, DummyMaster, :start, [])
    assert MasterConnection.connect(remote) == :ok

    assert capture_log(fn ->
      Cluster.kill_node(remote)
      :sys.get_state(MasterConnection) # Wait for handle_info to finish
    end) =~ "Master `#{remote}` disconnected"
  end

end
