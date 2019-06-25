# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.RegistryTest do
  use ExUnit.Case, async: true
  import Skitter.{Component, Registry}

  setup_all do
    [
      named: defcomponent(Name, [in: ignore], do: nil),
      unnamed: defcomponent([in: ignore], do: nil)
    ]
  end

  test "automatic registration", %{named: named} do
    assert get(Name) == named
  end

  test "registering nameless components returns component", %{unnamed: comp} do
    assert put_if_named(comp) == comp
  end

  test "duplicate name returns error", %{named: comp} do
    assert_raise Skitter.DefinitionError, ~r/`.*` is already in use/, fn ->
      put_if_named(comp)
    end
  end
end
