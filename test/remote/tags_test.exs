# Copyright 2018 - 2021, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Remote.TagsTest do
  use ExUnit.Case, async: true

  alias Skitter.Remote.{Registry, Tags}

  setup do
    Tags.start_link()
  end

  test "searching by tag" do
    Tags.add(:foo, [:a, :b])
    Tags.add(:bar, [:b, :c])

    [a, b, c] = Enum.map([:a, :b, :c], &Tags.workers_with/1)
    assert :foo in a
    assert :foo in b
    assert :bar in b
    assert :bar in c
  end

  test "listing node tags" do
    Tags.add(:foo, [:a, :b])
    tags = Tags.of_worker(:foo)
    assert :a in tags
    assert :b in tags
  end

  test "retrieving all tags" do
    Registry.start_link()
    Registry.add(:foo, :worker)
    Registry.add(:bar, :worker)

    Tags.add(:foo, [:a, :b])
    Tags.add(:bar, [:b, :c])

    all = Tags.of_all_workers()

    assert :a in all[:foo]
    assert :b in all[:foo]
    assert :b in all[:bar]
    assert :c in all[:bar]
  end
end
