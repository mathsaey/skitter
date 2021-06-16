# Copyright 2018 - 2021, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.RegistryTest do
  use ExUnit.Case, async: false
  alias Skitter.Runtime.Registry, as: Reg

  setup do
    Reg.start_link()
  end

  test "adding nodes" do
    Reg.add(:foo)
    assert :foo in Reg.all()
    assert Reg.connected?(:foo)
  end

  test "removing nodes" do
    Reg.add(:foo)
    assert :foo in Reg.all()
    Reg.remove(:foo)
    assert :foo not in Reg.all()
  end

  test "removing everything" do
    Reg.add(:foo)
    Reg.add(:bar)
    Reg.remove_all()
    assert :foo not in Reg.all()
    assert :bar not in Reg.all()
  end

  test "searching by tag" do
    Reg.add(:foo, [:a, :b])
    Reg.add(:bar, [:b, :c])

    [a, b, c] = Enum.map([:a, :b, :c], &Reg.with_tag/1)
    assert :foo in a
    assert :foo in b
    assert :bar in b
    assert :bar in c
  end

  test "listing node tags" do
    Reg.add(:foo, [:a, :b])
    tags = Reg.tags(:foo)
    assert :a in tags
    assert :b in tags
  end

  test "retrieving all tags" do
    Reg.add(:foo, [:a, :b])
    Reg.add(:bar, [:b, :c])

    all = Reg.all_with_tags()

    assert :a in all[:foo]
    assert :b in all[:foo]
    assert :b in all[:bar]
    assert :c in all[:bar]
  end
end
