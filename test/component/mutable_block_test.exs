# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Component.MutableBlockTest.Helpers do
  def var() do
    var = Macro.var(:var, __MODULE__)
    quote(do: var!(unquote(var), unquote(__MODULE__)))
  end

  defmacro send(), do: quote(do: send(self(), unquote(var())))
  defmacro write(val), do: quote(do: unquote(var()) = unquote(val))

  defmacro transform(do: body) do
    body = Skitter.Component.MutableBlock.transform(body, var())
    quote do
      unquote(var()) = nil
      unquote(body)
    end
  end
end

defmodule Skitter.Component.MutableBlockTest do
  use ExUnit.Case, async: true

  import Skitter.Component.MutableBlock
  import __MODULE__.Helpers

  test "if normal bodies remain unchanged" do
    block =
      quote do
        a = 10
        a * 30
      end

    single = quote do: 10

    assert single == transform(single, var())
    assert block == transform(block, var())
  end

  test "if" do
    val =
      transform do
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
      transform do
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

  test "case" do
    res = transform do
      case_res = case :some_value do
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
