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
      val + x ~> out
    end
  end

  setup do
    {:ok, pid} = start_supervised(TransientInstance.supervisor())
    [sup: pid]
  end

  test "if the supervisor is started correctly", c do
    assert Process.alive?(c[:sup])
  end

  test "if loading works correctly", c do
    {:ok, {ref, sup}} = TransientInstance.load(c[:sup], AddX, 10)
    term = :persistent_term.get({TransientInstance, ref})
    {:ok, inst} = Skitter.Component.init(AddX, 10)
    assert term == inst
    assert sup == c[:sup]
  end

  test "if reacting works", c do
    {:ok, arg} = TransientInstance.load(c[:sup], AddX, 10)
    {:ok, _, ref} = TransientInstance.react(arg, [100])
    assert_receive {:react_finished, ^ref, [out: 110]}
  end
end
