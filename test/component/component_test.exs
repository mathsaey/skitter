# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.ComponentTest do
  use ExUnit.Case, async: true
  import Skitter.Test.Assertions

  alias Skitter.Registry
  alias Skitter.Component
  alias Skitter.Component.Callback

  import Skitter.Component
  doctest Skitter.Component

  describe "defcomponent" do
    test "fields extraction" do
      comp =
        defcomponent in: [] do
          fields a, b, c
        end

      assert comp.fields == [:a, :b, :c]
    end

    test "callback extraction in block" do
      comp =
        defcomponent in: [] do
          react _ do
          end
        end

      assert Map.has_key?(comp.callbacks, :react)
    end

    test "callback extraction without block" do
      comp = defcomponent([in: []], do: react(_, do: nil))
      assert Map.has_key?(comp.callbacks, :react)
    end

    test "reuse directives" do
      comp = defcomponent in: [pid] do
        require Integer
        import String, only: [to_integer: 1]
        alias String, as: S

        cb pid do
          send(pid, {:import, to_integer("1")})
          send(pid, {:alias, S.to_integer("2")})
          send(pid, {:require, Integer.is_odd(3)})
        end
      end

      call(comp, :cb, %{}, [self()])

      assert_receive {:import, 1}
      assert_receive {:alias, 2}
      assert_receive {:require, true}
    end

    test "name registration" do
      c = defcomponent(__MODULE__.Named, [in: ignore], do: nil)
      assert Registry.get(__MODULE__.Named) == c
    end

    test "errors" do
      assert_definition_error ~r/.*: Invalid syntax: `:foo`/ do
        defcomponent(Test, [in: :foo], do: nil)
      end

      assert_definition_error ~r/.*: Invalid syntax: `5`/ do
        defcomponent(Test, [in: []], do: (fields a, b, 5))
      end

      assert_definition_error ~r/.*: Invalid port list: `.*`/ do
        defcomponent(Test, [extra: foo], do: nil)
      end

      assert_definition_error ~r/.*: Only one fields declaration is allowed: `.*`/ do
        defcomponent Test, in: [] do
          fields a, b, c
          fields x, y, z
        end
      end

      assert_definition_error ~r/.*: Only one handler declaration is allowed: `.*`/ do
        defcomponent in: [] do
          handler Handler1
          handler Handler2
        end
      end

      assert_definition_error ~r/`.*` is not defined/ do
        defcomponent in: [] do
          handler DoesNotExist
        end
      end

      assert_definition_error ~r/`.*` is not a valid component handler/ do
        defcomponent in: [] do
          handler 5
        end
      end

      assert_definition_error ~r/`.*` is not a valid component handler/ do
        h = defcomponent [in: []], do: nil
        defcomponent in: [] do
          handler h
        end
      end
    end
  end
end
