# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.RuntimeComponentTest do
  use ExUnit.Case, async: true

  import Skitter.Component, only: [component: 3]
  alias Skitter.Runtime.Component

  component Transient, in: val, out: val do
    react val do
      val ~> val
    end
  end

  component Permanent, in: val, out: curr do
    effect state_change
    fields ctr

    init x do
      ctr <~ x
    end

    react _ do
      ctr <~ ctr + 1
      ctr ~> curr
    end
  end

  describe "permanent instance" do
    alias Skitter.Runtime.Component.PermanentInstance

    test "loading" do
      {:ok, inst} = PermanentInstance.load(Permanent, 5)
      %PermanentInstance{instance: instance} = :sys.get_state(inst.ref)
      assert instance.state == %{ctr: 5}
    end

    test "reacting" do
      {:ok, inst} = PermanentInstance.load(Permanent, 5)
      {:ok, pid, ref} = PermanentInstance.react(inst, [:foo])

      %PermanentInstance{instance: instance} = :sys.get_state(pid)
      assert_receive {:react_finished, ^ref, [curr: 6]}
      assert instance.state == %{ctr: 6}
    end
  end

  describe "transient instance" do
    alias Skitter.Runtime.Component.TransientInstance

    test "loading" do
      {:ok, instance} = TransientInstance.load(Transient, nil)
      {:ok, inst} = Skitter.Component.init(Transient, nil)
      term = :persistent_term.get(instance.ref)
      assert term == inst
    end

    test "reacting" do
      {:ok, inst} = TransientInstance.load(Transient, nil)
      {:ok, _, ref} = TransientInstance.react(inst, [100])
      assert_receive {:react_finished, ^ref, [val: 100]}
    end
  end

  describe "arbitrary instance" do
    test "if permanent instances work as they should" do
      {:ok, c} = Component.load(Permanent, 0)
      {:ok, _, r1} = Component.react(c, [nil])
      {:ok, _, r2} = Component.react(c, [nil])
      assert_receive {:react_finished, ^r1, [curr: 1]}
      assert_receive {:react_finished, ^r2, [curr: 2]}
    end

    test "if transient instances work correctly" do
      {:ok, c} = Component.load(Transient, nil)
      {:ok, _, r1} = Component.react(c, [:foo])
      {:ok, _, r2} = Component.react(c, [:bar])
      assert_receive {:react_finished, ^r1, [val: :foo]}
      assert_receive {:react_finished, ^r2, [val: :bar]}
    end
  end
end
