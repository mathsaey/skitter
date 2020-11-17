# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Remote.HandlerTest do
  @moduledoc false
  alias Skitter.Remote.{HandlerSupervisor, HandlerServer, Dispatcher, Test.MapSetHandler}
  use Skitter.Remote.Test.Case, handlers: [test_mode: MapSetHandler]

  defp handler_pid do
    [{_, pid, _, _}] = Supervisor.which_children(HandlerSupervisor)
    pid
  end

  defp handler_state do
    {_, state} = :sys.get_state(handler_pid())
    state
  end

  test "gets initialized" do
    assert handler_state() == MapSet.new()
  end

  test "can accept connections" do
    Dispatcher.dispatch(Node.self(), :test_mode, {:accept, Node.self()})
    assert Node.self() in handler_state()
  end

  test "can reject connections" do
    Dispatcher.dispatch(Node.self(), :reject, {:accept, Node.self()})
    assert handler_state() == MapSet.new()
  end

  test "can remove connections" do
    Dispatcher.dispatch(Node.self(), :test_mode, {:accept, Node.self()})
    assert Node.self() in handler_state()
    HandlerServer.remove(handler_pid(), Node.self())
    assert handler_state() == MapSet.new()
  end

  @tag remote: [remote: []]
  test "detects failure", %{remote: remote} do
    Cluster.rpc(remote, Dispatcher, :dispatch, [Node.self(), :test_mode, {:accept, remote}])
    assert remote in handler_state()
    Cluster.kill_node(remote)
    assert handler_state() == MapSet.new()
  end
end
