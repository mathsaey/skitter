# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.RemoteTest do
  use Skitter.Runtime.Test.ClusterCase, async: false

  alias Skitter.Runtime
  alias Skitter.Runtime.Remote
  alias Skitter.Runtime.Test.{DummyRemote, Func}

  setup_all do
    Runtime.publish(:test_runtime)
  end

  describe "connect" do
    test "discovery errors are propagated" do
      assert Remote.connect(:"test@127.0.0.1", :mode, RemoteServer) == {:error, :not_distributed}
    end

    @tag distributed: [remote: [{Runtime, :publish, [:wrong_mode]}]]
    test "to a wrong mode fails", %{remote: remote} do
      assert Remote.connect(remote, :mode, RemoteServer) == {:error, :mode_mismatch}
    end

    @tag distributed: [remote: [{DummyRemote, :start, [RemoteServer, :mode, false]}]]
    test "can be rejected", %{remote: remote} do
      assert Remote.connect(remote, :mode, RemoteServer) == {:error, :rejected}
    end

    @tag distributed: [remote: [{DummyRemote, :start, [RemoteServer, :mode, true]}]]
    test "successfully", %{remote: remote} do
      assert Remote.connect(remote, :mode, RemoteServer) == :ok
    end
  end

  describe "accepting" do
    @tag distributed: [remote: [{Runtime, :publish, [:wrong_mode]}]]
    test "rejects incorrect modes", %{remote: remote} do
      assert not Remote.accept(remote, :mode)
    end

    @tag distributed: [remote: [{Runtime, :publish, [:mode]}]]
    test "successfully", %{remote: remote} do
      assert Remote.accept(remote, :mode)
    end
  end

  describe "remote code execution" do
    @tag distributed: [remote: []]
    test "on a single node using mfa", %{remote: remote} do
      assert Remote.on(remote, Node, :self, []) == remote
    end

    @tag distributed: [remote: []]
    test "on a single node using func", %{remote: remote} do
      assert Remote.on(remote, Func.get()) == remote
    end

    @tag distributed: [remote1: [], remote2: [], remote3: []]
    test "on many nodes using mfa", %{remote1: remote1, remote2: remote2, remote3: remote3} do
      res = Remote.on_many([remote1, remote2, remote3], Node, :self, [])
      assert res == [remote1, remote2, remote3]
    end

    @tag distributed: [remote1: [], remote2: [], remote3: []]
    test "on many nodes using funcs", %{remote1: remote1, remote2: remote2, remote3: remote3} do
      res = Remote.on_many([remote1, remote2, remote3], Func.get())
      assert res == [remote1, remote2, remote3]
    end
  end
end
