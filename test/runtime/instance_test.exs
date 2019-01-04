# Copyright 2018, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.InstanceTest do
  use ExUnit.Case, async: true

  import Skitter.Component, only: [component: 3]
  alias Skitter.Runtime.Instance

  component TestComponent, in: val, out: current do
    effect state_change
    fields ctr

    init x do
      ctr <~ x
    end

    react _val do
      ctr <~ ctr + 1
      ctr ~> current
    end
  end

  test "if the supervisor can be started correctly" do
    assert {:ok, pid} = start_supervised(Instance.supervisor())
    assert Process.alive?(pid)
  end

  test "if the server can be started as a part of a supervisor" do
    {:ok, sup} = start_supervised(Instance.supervisor())
    {:ok, pid} = Instance.start_supervised_instance(sup, :id, TestComponent, 5)
    assert Process.alive?(pid)
  end

  test "if the server can be started unsupervised" do
    {:ok, pid} = Instance.start_linked_instance(:id, TestComponent, 5)
    assert Process.alive?(pid)
  end

  test "if initialization works correctly" do
    {:ok, pid} = Instance.start_linked_instance(:id, TestComponent, 5)
    assert Instance.id(pid) == :id

    {instance, _id} = :sys.get_state(pid)
    assert instance.state == [ctr: 5]
  end

  test "if reacting works" do
    {:ok, pid} = Instance.start_linked_instance(:id, TestComponent, 5)
    {:ok, spits} = Instance.react(pid, [:foo])

    {instance, _id} = :sys.get_state(pid)
    assert instance.state == [ctr: 6]
    assert spits == [current: 6]
  end
end
