# Copyright 2018 - 2022, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Remote.HandlerTest do
  @moduledoc false

  alias Skitter.Remote.{Handler, Test.MapSetHandler}
  use Skitter.Remote.Test.Case, mode: :test_mode, handlers: [test_mode: MapSetHandler]

  defp handler_state(mode \\ :test_mode) do
    {_, state} = :sys.get_state(Handler.get_pid(mode))
    state
  end

  test "gets initialized" do
    assert handler_state() == MapSet.new()
  end

  test "can accept connections" do
    Handler.accept_local(:test_mode, Node.self())
    assert Node.self() in handler_state()
  end

  test "can reject connections" do
    Handler.accept_local(:reject, Node.self())
    assert handler_state() == MapSet.new()
  end

  test "can remove connections" do
    Handler.accept_local(:test_mode, Node.self())
    assert Node.self() in handler_state()
    Handler.remove(:test_mode, Node.self())
    assert handler_state() == MapSet.new()
  end

  @tag remote: [remote: []]
  test "detects failure", %{remote: remote} do
    Cluster.rpc(remote, Handler, :accept_remote, [Node.self(), :test_mode])
    assert remote in handler_state()
    Cluster.kill_node(remote)
    assert handler_state() == MapSet.new()
  end
end
