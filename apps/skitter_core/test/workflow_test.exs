# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.WorkflowTest do
  use ExUnit.Case, async: true

  alias Skitter.{Component, Workflow}

  doctest Skitter.Workflow

  test "fetch" do
    w = %Workflow{nodes: %{inst: {%Component{}, []}}}

    assert w[:doesnotexist] == nil
    assert w[:inst] == {%Component{}, []}
  end

  test "pop" do
    w = %Workflow{nodes: %{inst: {%Component{}, []}}}

    {v, w} = Access.pop(w, :doesnotexist)
    assert w[:inst] == {%Component{}, []}
    assert v == nil

    {v, w} = Access.pop(w, :inst)
    assert v == {%Component{}, []}
    assert w[:inst] == nil
  end

  test "get_and_update" do
    w = %Workflow{nodes: %{inst: {%Component{}, []}}}

    {v, w} = Access.get_and_update(w, :inst, fn _ -> :pop end)
    assert v == {%Component{}, []}
    assert w[:inst] == nil
  end
end
