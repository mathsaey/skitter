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

  test "`:none` state capability" do
    c =
      defcallback([:field], [], []) do
        10
      end

    assert c.state_capability == :none
    assert Callback.call(c, %{field: nil}, []).state == nil
  end

  test "`:read` state capability" do
    c =
      defcallback([:field], [], []) do
        field
      end

    assert c.state_capability == :read

    res = Callback.call(c, %{field: 50}, [])
    assert res.state == nil
    assert res.result == 50
  end

  test "`:readwrite` state capability" do
    c =
      defcallback([:field], [], []) do
        field <~ 30
      end

    assert c.state_capability == :readwrite
    assert Callback.call(c, %{field: nil}, []).state == %{field: 30}
  end

  test "no publish" do
    c =
      defcallback([], [:out], []) do
        5
      end

    assert c.publish_capability == false
    assert Callback.call(c, %{}, []).publish == nil
  end

  test "publish" do
    c =
      defcallback([], [:out], []) do
        5 ~> out
      end

    assert c.publish_capability == true
    assert Callback.call(c, %{}, []).publish == [out: 5]
  end

  test "arguments and arity" do
    c1 =
      defcallback([], [], [arg]) do
        arg
      end

    c2 =
      defcallback([], [], [arg1, arg2]) do
        arg1 + arg2
      end

    assert c1.arity == 1
    assert c2.arity == 2
    assert Callback.call(c1, %{}, [10]).result == 10
    assert Callback.call(c2, %{}, [10, 20]).result == 30
  end

  test "errors" do
    assert_definition_error ~r/.*: Invalid syntax: `foo`/ do
      defcallback([], [], [], do: 5 ~> :foo)
    end

    assert_definition_error ~r/.*: Invalid field: .*/ do
      defcallback([:field], [], [], do: another_field <~ 5)
    end

    assert_definition_error ~r/.*: Invalid out port: .*/ do
      defcallback([], [:out], [], do: 5 ~> wrong_port)
    end
  end
end
