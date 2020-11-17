# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Remote.BeaconTest do
  use Skitter.Remote.Test.Case
  alias Skitter.Remote.Beacon

  test ":not_distributed when local node not alive" do
    assert Beacon.verify_remote(:foo) == {:error, :not_distributed}
  end

  @tag :remote
  test "errors when connection is not possible" do
    assert Beacon.verify_remote(:"foo@127.0.0.1") == {:error, :not_connected}
  end

  @tag :remote
  test "does not accept non-skitter nodes" do
    remote = Cluster.spawn_node(:not_skitter, nil, [])
    assert Beacon.verify_remote(remote) == {:error, :not_skitter}
    assert remote not in Node.list(:connected)
  end

  @tag remote: [remote: [{Beacon, :set_mode, [:test_mode]}]]
  test "can connect to skitter nodes", %{remote: remote} do
    assert Beacon.verify_remote(remote) == {:ok, :test_mode}
  end
end
