# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.RemoteTest do
  use Skitter.Remote.Test.ClusterCase, async: false
  alias Skitter.Remote

  @tag distributed: [
         remote: [
           {Remote.Beacon, :override_mode, [:test_mode]},
           {Remote.Test.Receiver, :start_link, [:default]}
         ]
       ]
  test "connect", %{remote: remote} do
    assert {:ok, :test_mode, _} = Remote.connect(remote)
  end

  describe "errors" do
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
      assert Remote.connect(remote) == {:error, :nomode}
    end

    @tag distributed: [remote: [{Remote.Beacon, :override_mode, [:test_mode]}]]
    test "when the remote node does not have handler for the local mode", %{remote: remote} do
      assert Remote.connect(remote) == {:error, :unknown_mode}
    end
  end
end
