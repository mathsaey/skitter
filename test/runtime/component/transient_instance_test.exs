# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.TransientInstanceTest do
  use ExUnit.Case, async: true

  import Skitter.Component, only: [component: 3]
  alias Skitter.Runtime.Component.TransientInstance

  component AddX, in: val, out: out do
    fields x

    init num do
      x <~ num
    end

    react val do
      # Sleep so we can do something while the process is reacting
      Process.sleep(10)
      val + x ~> out
    end
  end

  test "if the supervisor is started correctly" do
    TransientInstance.Supervisor
    |> GenServer.whereis()
    |> Process.alive?()
    |> assert()
  end

  test "if loading works correctly" do
    {:ok, ref} = TransientInstance.load(make_ref(), AddX, 10)
    term = :persistent_term.get({TransientInstance, ref})
    {:ok, inst} = Skitter.Component.init(AddX, 10)
    assert term == inst
  end

  test "if reacting happens as a part of a supervisor" do
    {:ok, arg} = TransientInstance.load(make_ref(), AddX, 10)
    {:ok, pid, _} = TransientInstance.react(arg, [100])

    children = DynamicSupervisor.which_children(TransientInstance.Supervisor)
    child = {:undefined, pid, :worker, [TransientInstance.Server]}
    assert child in children
  end

  test "if reacting works" do
    {:ok, arg} = TransientInstance.load(make_ref(), AddX, 10)
    {:ok, _, ref} = TransientInstance.react(arg, [100])
    assert_receive {:react_finished, ^ref, [out: 110]}
  end
end
