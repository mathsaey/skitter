# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.DSL.RegistryTest do
  use ExUnit.Case, async: true

  import Skitter.DSL.Registry
  alias Skitter.{Component, Workflow, DSL.DefinitionError}

  test "nameless registration returns value" do
    assert put_if_named(%Component{}) == %Component{}
    assert put_if_named(%Workflow{}) == %Workflow{}
  end

  test "insertion" do
    put_if_named(%Component{name: Cname})
    put_if_named(%Workflow{name: Wname})

    assert {Cname, %Component{name: Cname}} in get_all()
    assert {Wname, %Workflow{name: Wname}} in get_all()
    assert Cname in get_names()
    assert Wname in get_names()
  end

  test "duplicate name returns error" do
    put_if_named(%Component{name: CDupName})
    put_if_named(%Workflow{name: WDupName})

    assert_raise DefinitionError, ~r/`.*` is already in use/, fn ->
      put_if_named(%Component{name: CDupName})
    end

    assert_raise DefinitionError, ~r/`.*` is already in use/, fn ->
      put_if_named(%Workflow{name: WDupName})
    end
  end
end
