# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Component.CallbackTest do
  use ExUnit.Case, async: true
  import Skitter.Test.Assertions

  alias Skitter.Component.Callback
  alias Skitter.Component.Callback.Result

  import Skitter.Component.Callback
  doctest Skitter.Component.Callback

  describe "internal utility functions: " do
    test "check_permissions" do
      c1 = %Callback{state_capability: :read, publish_capability: true}
      assert check_permissions(c1, :readwrite, true) == true
      assert check_permissions(c1, :none, true) == false

      c2 = %Callback{state_capability: :none, publish_capability: true}
      assert check_permissions(c2, :none, true) == true
      assert check_permissions(c2, :none, false) == false

      c3 = %Callback{state_capability: :none, publish_capability: false}
      assert check_permissions(c3, :none, false) == true
      assert check_permissions(c3, :none, true) == true
    end

    test "check_arity" do
      c = %Callback{arity: 1}
      assert check_arity(c, 1) == true
      assert check_arity(c, 3) == false
      assert check_arity(c, -1) == true
    end

    test "call" do
      c =
        defcallback([:field], [:out], [arg1, arg2]) do
          field <~ (field + arg1)
          arg2 ~> out
          field
        end

      assert call(c, %{field: 1}, [2, 3]) == %Result{
               state: %{field: 3},
               publish: [out: 3],
               result: 3
             }
    end
  end

  describe "defcallback" do
    test "`:none` state capability" do
      c =
        defcallback([:field], [], []) do
          10
        end

      assert c.state_capability == :none
      assert call(c, %{field: nil}, []).state == nil
    end

    test "`:read` state capability" do
      c =
        defcallback([:field], [], []) do
          field
        end

      assert c.state_capability == :read

      res = call(c, %{field: 50}, [])
      assert res.state == nil
      assert res.result == 50
    end

    test "`:readwrite` state capability" do
      c =
        defcallback([:field], [], []) do
          field <~ 30
        end

      assert c.state_capability == :readwrite
      assert call(c, %{field: nil}, []).state == %{field: 30}
    end

    test "no publish" do
      c =
        defcallback([], [:out], []) do
          5
        end

      assert c.publish_capability == false
      assert call(c, %{}, []).publish == nil
    end

    test "publish" do
      c =
        defcallback([], [:out], []) do
          5 ~> out
        end

      assert c.publish_capability == true
      assert call(c, %{}, []).publish == [out: 5]
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
      assert call(c1, %{}, [10]).result == 10
      assert call(c2, %{}, [10, 20]).result == 30
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
end
