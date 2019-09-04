# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.RegistryTest do
  use ExUnit.Case, async: true

  import Skitter.Runtime.Registry
  import Skitter.{Component, Workflow}

  setup_all do
    [
      component: defcomponent([in: ignore], do: nil),
      workflow: defworkflow([in: ignore], do: nil)
    ]
  end

  test "nameless registration returns value", %{component: c, workflow: w} do
    assert put_if_named(c) == c
    assert put_if_named(w) == w
  end

  test "insertion", %{component: c, workflow: w} do
    c_named = %{c | name: ComponentInsertName}
    w_named = %{w | name: WorkflowInsertName}

    put_if_named(c_named)
    put_if_named(w_named)

    assert {c_named.name, c_named} in get_all()
    assert {w_named.name, w_named} in get_all()
  end

  test "duplicate name returns error", %{component: c, workflow: w} do
    c_named = %{c | name: ComponentDuplicateName}
    w_named = %{w | name: WorkflowDuplicateName}

    put_if_named(c_named)
    put_if_named(w_named)

    assert_raise Skitter.DefinitionError, ~r/`.*` is already in use/, fn ->
      put_if_named(c_named)
    end

    assert_raise Skitter.DefinitionError, ~r/`.*` is already in use/, fn ->
      put_if_named(w_named)
    end
  end
end
