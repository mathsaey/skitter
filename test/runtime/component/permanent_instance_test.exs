# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.PermanentInstanceTest do
  use ExUnit.Case, async: true

  import Skitter.Component, only: [component: 3]
  alias Skitter.Runtime.Component.PermanentInstance

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

  setup do
    {:ok, pid} = start_supervised(PermanentInstance.supervisor())
    [sup: pid]
  end

  test "if the supervisor is started correctly", c do
    assert Process.alive?(c[:sup])
  end

  test "if the server can be started as a part of a supervisor", c do
    {:ok, pid} = PermanentInstance.load(c[:sup], TestComponent, 5)
    children = DynamicSupervisor.which_children(c[:sup])
    child = {:undefined, pid, :worker, [PermanentInstance.Server]}
    assert child in children
  end

  test "if IDs are unique", c do
    {:ok, p1} = PermanentInstance.load(c[:sup], TestComponent, 5)
    {:ok, p2} = PermanentInstance.load(c[:sup], TestComponent, 5)

    %PermanentInstance.Server{id: id1} = :sys.get_state(p1)
    %PermanentInstance.Server{id: id2} = :sys.get_state(p2)

    refute id1 == id2
  end

  test "if state initialization works correctly", c do
    {:ok, pid} = PermanentInstance.load(c[:sup], TestComponent, 5)

    %PermanentInstance.Server{instance: instance} = :sys.get_state(pid)
    assert instance.state == [ctr: 5]
  end

  test "if reacting works", c do
    {:ok, pid} = PermanentInstance.load(c[:sup], TestComponent, 5)
    {:ok, pid, ref} = PermanentInstance.react(pid, [:foo])

    %PermanentInstance.Server{instance: instance} = :sys.get_state(pid)
    assert_receive {:react_finished, ^ref, [current: 6]}
    assert instance.state == [ctr: 6]
  end
end
