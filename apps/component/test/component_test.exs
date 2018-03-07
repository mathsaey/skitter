defmodule Skitter.ComponentTest do
  use ExUnit.Case
  doctest Skitter.Component

  test "greets the world" do
    assert Skitter.Component.hello() == :world
  end
end
