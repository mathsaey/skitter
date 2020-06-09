# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Worker.MasterTest do
  use Skitter.Runtime.Test.ClusterCase, async: false

  alias Skitter.Runtime
  alias Skitter.Runtime.Test.DummyRemote

  setup_all do
    Runtime.publish(:test_runtime)
  end

  describe "connect" do
    test "discovery errors are propagated" do
      assert Runtime.connect(:"test@127.0.0.1", :mode, RemoteServer) == {:error, :not_distributed}
    end

    @tag distributed: [remote: [{Runtime, :publish, [:wrong_mode]}]]
    test "to a wrong mode fails", %{remote: remote} do
      assert Runtime.connect(remote, :mode, RemoteServer) == {:error, :mode_mismatch}
    end

    @tag distributed: [remote: [{DummyRemote, :start, [RemoteServer, :mode, false]}]]
    test "can be rejected", %{remote: remote} do
      assert Runtime.connect(remote, :mode, RemoteServer) == {:error, :rejected}
    end

    @tag distributed: [remote: [{DummyRemote, :start, [RemoteServer, :mode, true]}]]
    test "successfully", %{remote: remote} do
      assert Runtime.connect(remote, :mode, RemoteServer) == :ok
    end
  end

  describe "accepting" do
    @tag distributed: [remote: [{Runtime, :publish, [:wrong_mode]}]]
    test "rejects incorrect modes", %{remote: remote} do
      assert not Runtime.accept(remote, :mode)
    end

    @tag distributed: [remote: [{Runtime, :publish, [:mode]}]]
    test "successfully", %{remote: remote} do
      assert Runtime.accept(remote, :mode)
    end
  end
end
