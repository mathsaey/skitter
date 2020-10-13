# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.DSL.MutableTest.Helpers do
  def var() do
    var = Macro.var(:var, __MODULE__)
    quote(do: var!(unquote(var), unquote(__MODULE__)))
  end

  defmacro send(), do: quote(do: send(self(), unquote(var())))
  defmacro write(val), do: quote(do: unquote(var()) = unquote(val))

  defmacro make_mutable_with_initial_value(do: body) do
    body = Skitter.DSL.Mutable.make_mutable_in_block(body, var())

    quote do
      unquote(var()) = nil
      unquote(body)
    end
  end
end

defmodule Skitter.DSL.MutableTest do
  use ExUnit.Case, async: true
  import Skitter.DSL.Mutable

  import __MODULE__.Helpers

  test "does not modify normal bodies" do
    block =
      quote do
        a = 10
        a * 30
      end

    single = quote do: 10

    assert single == make_mutable_in_block(single, var())
    assert block == make_mutable_in_block(block, var())
  end

  test "works with if" do
    val =
      make_mutable_with_initial_value do
        if_res =
          if true do
            write(:foo)
            42
          end

        send()
        if_res
      end

    assert val == 42
    assert_receive :foo

    val =
      make_mutable_with_initial_value do
        if_res =
          if false do
            :ignore
          else
            write(:bar)
            3
          end

        send()
        if_res
      end

    assert val == 3
    assert_receive :bar
  end

  test "works with case" do
    res =
      make_mutable_with_initial_value do
        case_res =
          case :some_value do
            :some_value ->
              write(:foo)
              :another_value
          end

        send()
        case_res
      end

    assert res == :another_value
    assert_receive :foo
  end
end
