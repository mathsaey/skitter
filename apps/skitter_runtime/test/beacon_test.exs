# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.BeaconTest do
  use Skitter.Runtime.Test.ClusterCase, async: false
  import ExUnit.CaptureLog

  alias Skitter.Runtime.Remote.Beacon

  defp version do
    Application.spec(:skitter_runtime, :vsn)
  end

  test "initial mode is nil" do
    Supervisor.terminate_child(Skitter.Runtime.Application.Supervisor, Beacon)
    Supervisor.restart_child(Skitter.Runtime.Application.Supervisor, Beacon)
    assert GenServer.call(Beacon, :discover) == {version(), nil}
  end

  test "changing modes logs warning" do
    :ok = Beacon.publish(:beacon_test)
    assert GenServer.call(Beacon, :discover) == {version(), :beacon_test}

    assert capture_log(fn ->
             Beacon.publish(:changed)
             # Wait for cast to finish
             :sys.get_state(Beacon)
           end) =~ "Replacing `beacon_test` with `changed`"

    assert GenServer.call(Beacon, :discover) == {version(), :changed}
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

    @tag distributed: [remote: []]
    test "cannot connect to uninitialized nodes", %{remote: remote} do
      assert Beacon.discover(remote) == {:error, :uninitialized}
    end

    @tag distributed: [remote: [{Beacon, :publish, [:test_mode]}]]
    test "can connect to skitter nodes", %{remote: remote} do
      assert Beacon.discover(remote) == {:ok, :test_mode}
    end
  end
end
