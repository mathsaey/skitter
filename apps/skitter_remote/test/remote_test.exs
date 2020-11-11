# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.RemoteTest do
  use Skitter.Remote.Test.ClusterCase, async: false
  alias Skitter.Remote

  setup do
    Remote.set_local_mode(:test_mode)
  end

  @tag distributed: [
         remote: [
           {Remote, :set_local_mode, [:test_mode]},
           {Remote, :setup_handlers, [[test_mode: Skitter.Remote.Test.Handler]]}
         ]
       ]
  test "connect", %{remote: remote} do
    Remote.setup_handlers(test_mode: Skitter.Remote.Test.Handler)
    assert {:ok, :test_mode} = Remote.connect(remote)
  end

  describe "errors" do
    test "when node is not initialized" do
      Remote.set_local_mode(nil)
      assert Remote.connect(:"test@127.0.0.1") == {:error, :uninitialized_local}
    end

    test "when node is not distributed" do
      assert Remote.connect(:"test@127.0.0.1") == {:error, :not_distributed}
    end

    @tag :distributed
    test "when remote node is not reachable" do
      assert Remote.connect(:"test@127.0.0.1") == {:error, :not_connected}
    end

    @tag distributed: [remote: [{Application, :stop, [:skitter_remote]}]]
    test "when remote node is not a skitter runtime", %{remote: remote} do
      assert Remote.connect(remote) == {:error, :not_skitter}
    end

    @tag distributed: [remote: []]
    test "when the remote node does not have a mode", %{remote: remote} do
      assert Remote.connect(remote) == {:error, :uninitialized_remote}
    end

    @tag distributed: [remote: [{Remote, :set_local_mode, [:wrong_mode]}]]
    test "when the remote node does not have the correct mode", %{remote: remote} do
      assert Remote.connect(remote, :some_mode) == {:error, :mode_mismatch}
    end

    @tag distributed: [remote: [{Remote, :set_local_mode, [:test_mode]}]]
    test "when the remote node does not have handler for the local mode", %{remote: remote} do
      assert Remote.connect(remote) == {:error, :unknown_mode}
    end

    @tag distributed: [remote: [{Remote.Test.Handler, :setup, [:remote_mode]}]]
    test "when the remote handler rejects the connection attempt", %{remote: remote} do
      Remote.set_local_mode(:reject)
      Remote.setup_handlers(remote_mode: Skitter.Remote.Test.Handler)
      assert Remote.connect(remote) == {:error, :rejected}
    end
  end

  describe "remote code execution" do
    @tag distributed: [remote: []]
    test "on a single node using mfa", %{remote: remote} do
      assert Remote.on(remote, Node, :self, []) == remote
    end

    @tag distributed: [remote: []]
    test "on a single node using func", %{remote: remote} do
      assert Remote.on(remote, &Node.self/0) == remote
    end

    @tag distributed: [remote1: [], remote2: [], remote3: []]
    test "on many nodes using mfa", %{remote1: remote1, remote2: remote2, remote3: remote3} do
      res = Remote.on_many([remote1, remote2, remote3], Node, :self, [])
      assert res == [remote1, remote2, remote3]
    end

    @tag distributed: [remote1: [], remote2: [], remote3: []]
    test "on many nodes using funcs", %{remote1: remote1, remote2: remote2, remote3: remote3} do
      res = Remote.on_many([remote1, remote2, remote3], &Node.self/0)
      assert res == [remote1, remote2, remote3]
    end
  end
end
