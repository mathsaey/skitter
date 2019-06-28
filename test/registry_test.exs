# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.RegistryTest do
  use ExUnit.Case, async: true
  import Skitter.{Component, Workflow, Registry}

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

  test "duplicate name returns error", %{component: c, workflow: w} do
    c_named = %{c | name: ComponentName}
    w_named = %{w | name: WorkflowName}

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
