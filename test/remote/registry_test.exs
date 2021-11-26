# Copyright 2018 - 2021, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Remote.RegistryTest do
  use ExUnit.Case, async: false
  alias Skitter.Remote.Registry, as: Reg

  setup do
    Reg.start_link()
  end

  test "adding nodes" do
    Reg.add(:foo, :dummy)
    assert {:foo, :dummy} in Reg.all()
    assert Reg.connected?(:foo)
  end

  test "removing nodes" do
    Reg.add(:foo, :dummy)
    assert {:foo, :dummy} in Reg.all()
    Reg.remove(:foo)
    assert {:foo, :dummy} not in Reg.all()
    refute Reg.connected?(:foo)
  end

  test "removing everything" do
    Reg.add(:foo, :dummy)
    Reg.add(:bar, :dummy)
    Reg.remove_all()
    assert {:foo, :dummy} not in Reg.all()
    assert {:bar, :dummy} not in Reg.all()
    refute Reg.connected?(:foo)
    refute Reg.connected?(:bar)
  end

  test "finding workers and masters" do
    Reg.add(:foo, :master)
    Reg.add(:bar, :worker)
    Reg.add(:baz, :worker)

    assert :foo == Reg.master()
    assert :bar in Reg.workers()
    assert :baz in Reg.workers()
  end
end
