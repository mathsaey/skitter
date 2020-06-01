# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.BeaconTest do
  use ExUnit.Case, async: true

  alias Skitter.Runtime.Test.Cluster
  alias Skitter.Runtime.Beacon

  test "local mode" do
    assert GenServer.call(Beacon, :mode) == :not_specified
    :ok = Beacon.set_local_mode(:beacon_test)
    assert GenServer.call(Beacon, :mode) == :beacon_test
  end

  describe "discovery" do
    test "errors when local node not alive" do
      Node.stop()
      assert Beacon.discover(:foo) == {:error, :not_distributed}
    end

    test "errors when connection is not possible" do
      Cluster.ensure_distributed()
      assert Beacon.discover(:"foo@127.0.0.1") == {:error, :not_connected}
    end

    @tag :distributed
    test "does not accept non-skitter nodes" do
      remote = Cluster.spawn_node(:not_skitter, nil, [])
      assert Beacon.discover(remote) == {:error, :not_skitter}
      assert remote not in Node.list(:connected)
    end

    @tag :distributed
    test "can connect to skitter nodes" do
      remote = Cluster.spawn_node(:skitter, :skitter_runtime, [])
      assert Beacon.discover(remote) == {:ok, :not_specified}

      Cluster.rpc(remote, Beacon, :set_local_mode, [:test_mode])
      assert Beacon.discover(remote) == {:ok, :test_mode}
    end
  end
end
