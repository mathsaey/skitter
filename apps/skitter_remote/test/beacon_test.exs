# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Remote.BeaconTest do
  use Skitter.Remote.Test.ClusterCase, async: false
  alias Skitter.Remote.Beacon

  test "starts uninitialized" do
    assert Beacon.verify_local() == {:error, :uninitialized_local}
  end

  test ":not_distributed when local node not alive" do
    assert Beacon.verify_remote(:foo) == {:error, :not_distributed}
  end

  @tag :distributed
  test "errors when connection is not possible" do
    assert Beacon.verify_remote(:"foo@127.0.0.1") == {:error, :not_connected}
  end

  @tag :distributed
  test "does not accept non-skitter nodes" do
    remote = Cluster.spawn_node(:not_skitter, nil, [])
    assert Beacon.verify_remote(remote) == {:error, :not_skitter}
    assert remote not in Node.list(:connected)
  end

  @tag distributed: [remote: []]
  test "cannot connect to uninitialized nodes", %{remote: remote} do
    assert Beacon.verify_remote(remote) == {:error, :uninitialized_remote}
  end

  @tag distributed: [remote: [{Beacon, :set_mode, [:test_mode]}]]
  test "can connect to skitter nodes", %{remote: remote} do
    assert Beacon.verify_remote(remote) == {:ok, :test_mode}
  end
end
