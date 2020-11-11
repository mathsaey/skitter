# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Remote.HandlerTest do
  @moduledoc false
  use Skitter.Remote.Test.ClusterCase, async: false
  alias Skitter.Remote.{HandlerServer, Dispatcher}

  setup do
    {:ok, pid} = start_supervised({HandlerServer, [Skitter.Remote.Test.Handler, :default]})
    [handler: pid]
  end

  defp state(pid) do
    {_, state} = :sys.get_state(pid)
    state
  end

  test "gets initialized", %{handler: pid} do
    assert state(pid) == MapSet.new()
  end

  test "can accept connections", %{handler: pid} do
    Dispatcher.dispatch(Node.self(), :accept, {:accept, Node.self()})
    assert Node.self() in state(pid)
  end

  test "can reject connections", %{handler: pid} do
    Dispatcher.dispatch(Node.self(), :reject, {:accept, Node.self()})
    assert state(pid) == MapSet.new()
  end

  test "can remove connections", %{handler: pid} do
    Dispatcher.dispatch(Node.self(), :accept, {:accept, Node.self()})
    assert Node.self() in state(pid)
    HandlerServer.remove(pid, Node.self())
    assert state(pid) == MapSet.new()
  end

  @tag distributed: [remote: []]
  test "detects failure", %{handler: pid, remote: remote} do
    Cluster.rpc(remote, Dispatcher, :dispatch, [Node.self(), :accept, {:accept, remote}])
    assert remote in state(pid)
    Cluster.kill_node(remote)
    assert state(pid) == MapSet.new()
  end
end
