# Copyright 2018, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.MatcherTest do
  use ExUnit.Case, async: true

  import Skitter.Component
  import Skitter.Workflow

  alias Skitter.Runtime.Workflow
  import Skitter.Runtime.Workflow.Matcher

  component Test, in: [x, y] do
    react _x, _y do
    end
  end

  defmodule Wrapper do
    workflow MatcherTest, in: s do
      s ~> c1.x
      s ~> c1.y
      s ~> c2.x
      s ~> c2.y

      c1 = instance Test
      c2 = instance Test
    end
  end

  setup_all do
    {:ok, ref} = Workflow.load(Wrapper.MatcherTest)
    instances = Workflow.Store.get_instances(ref)
    [instances: instances]
  end

  test "If adding tokens works", %{instances: inst} do
    {:ok, map} = add(new(), {:c1, :x, :foo}, inst)
    {:ok, map} = add(map, {:c2, :y, :bar}, inst)

    assert map == %{c1: {%{x: :foo}, 2}, c2: {%{y: :bar}, 2}}

    {:ready, map, id, entry} = add(map, {:c1, :y, :baz}, inst)
    assert map == %{c2: {%{y: :bar}, 2}}
    assert entry == [:foo, :baz]
    assert id == :c1
  end
end
