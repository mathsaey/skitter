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

  def wf do
    workflow do
      source _ ~> {c1.x, c1.y, c2.x, c2.y}
      c1 = {Test, _}
      c2 = {Test, _}
    end
  end

  setup_all do
    {:ok, ref} = Workflow.load(wf())
    [ref: ref]
  end

  test "If adding tokens works", %{ref: wf} do
    {:ok, map} = add(new(), {:c1, :x, :foo}, wf)
    {:ok, map} = add(map, {:c2, :y, :bar}, wf)

    assert map == %{c1: {%{x: :foo}, 2}, c2: {%{y: :bar}, 2}}

    {:ready, map, id, entry} = add(map, {:c1, :y, :baz}, wf)
    assert map == %{c2: {%{y: :bar}, 2}}
    assert entry == [:foo, :baz]
    assert id == :c1
  end
end
