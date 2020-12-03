# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.DSL.CallbackTest do
  use ExUnit.Case, async: true
  import Skitter.DSL.Test.Assertions

  alias Skitter.Callback
  alias Skitter.Callback.Result

  import Skitter.DSL.Callback
  doctest Skitter.DSL.Callback

  test "no state access" do
    c =
      callback([:field], []) do
        () ->
          10
      end

    refute c.read?
    refute c.write?
  end

  test "readonly state" do
    c =
      callback([:field], []) do
        () ->
          field
      end

    assert c.read?
    refute c.write?
    assert Callback.call(c, %{field: 50}, []).result == 50
  end

  test "write only state" do
    c =
      callback([:field], []) do
        () ->
          field <~ 30
      end

    refute c.read?
    assert c.write?

    assert Callback.call(c, %{field: nil}, []).state == %{field: 30}
  end

  test "read/write state" do
    c =
      callback([:field], []) do
        () ->
          field <~ (field + 10)
      end

    assert c.read?
    assert c.write?

    assert Callback.call(c, %{field: 20}, []).state == %{field: 30}
  end

  test "no publish" do
    c =
      callback([], [:out]) do
        () ->
          5
      end

    refute c.publish?
    assert Callback.call(c, %{}, []).publish == []
  end

  test "publish" do
    c =
      callback([], [:out]) do
        () ->
          5 ~> out
      end

    assert c.publish?
    assert Callback.call(c, %{}, []).publish == [out: 5]
  end

  test "arguments and arity" do
    c1 =
      callback([], []) do
        arg -> arg
      end

    c2 =
      callback([], []) do
        arg1, arg2 -> arg1 + arg2
      end

    assert c1.arity == 1
    assert c2.arity == 2
    assert Callback.call(c1, %{}, [10]).result == 10
    assert Callback.call(c2, %{}, [10, 20]).result == 30
  end

  test "multiple clauses" do
    c =
      callback([], []) do
        :foo -> :bar
        %{foo: x} -> x
      end

    assert Callback.call(c, %{}, [:foo]).result == :bar
    assert Callback.call(c, %{}, [%{foo: 10}]).result == 10
  end

  test "errors" do
    assert_definition_error ~r/.*: Invalid syntax: `foo`/ do
      callback([], [], do: (() -> 5 ~> :foo))
    end

    assert_definition_error ~r/.*: Callback clauses must have the same arity/ do
      callback([], []) do
        arg -> arg
        arg1, arg2 -> {arg1, arg2}
      end
    end

    assert_definition_error ~r/.*: Invalid field: .*/ do
      callback([:field], [], do: (() -> another_field <~ 5))
    end

    assert_definition_error ~r/.*: Invalid out port: .*/ do
      callback([], [:out], do: (() -> 5 ~> wrong_port))
    end
  end
end
