# Copyright 2018, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.MatcherTest do
  use ExUnit.Case, async: true

  import Skitter.Runtime.Matcher
  import Skitter.Component
  import Skitter.Workflow

  component Test, in: [x, y] do
    react x, y do
      x + y
    end
  end

  wf = workflow do
    source _ ~> c.x, c.y
    c = {Identity, _}
  end

  test "If the basic functions work correctly" do
    assert %{} == new()
    assert empty?(new())
    refute empty?(%{foo: :bar})
  end

  test "If adding tokens works" do
    {:ok, map} = add(new(), {:c, :x}, :foo, wf)
    assert map == 5
  end
end
