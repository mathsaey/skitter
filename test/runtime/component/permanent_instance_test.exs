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

  test "if the supervisor is started correctly" do
    PermanentInstance.Supervisor
    |> GenServer.whereis()
    |> Process.alive?()
    |> assert()
  end

  test "if the server is started as a part of the supervisor" do
    {:ok, inst} = PermanentInstance.load(TestComponent, 5)

    children = DynamicSupervisor.which_children(PermanentInstance.Supervisor)
    child = {:undefined, inst.ref, :worker, [PermanentInstance.Server]}
    assert child in children
  end

  test "if state initialization works correctly" do
    {:ok, inst} = PermanentInstance.load(TestComponent, 5)

    %PermanentInstance.Server{instance: instance} = :sys.get_state(inst.ref)
    assert instance.state == %{ctr: 5}
  end

  test "if reacting works" do
    {:ok, inst} = PermanentInstance.load(TestComponent, 5)
    {:ok, pid, ref} = PermanentInstance.react(inst, [:foo])

    %PermanentInstance.Server{instance: instance} = :sys.get_state(pid)
    assert_receive {:react_finished, ^ref, [current: 6]}
    assert instance.state == %{ctr: 6}
  end
end
