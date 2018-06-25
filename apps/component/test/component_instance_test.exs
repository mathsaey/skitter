defmodule Skitter.ComponentInstanceTest do
  use ExUnit.Case, async: true
  alias Skitter.Component.Instance

  doctest Skitter.Component.Instance

  test "If getters work" do
    inst = Instance.create(:foo, :bar)

    assert Instance.component(inst) == :foo
    assert Instance.state(inst) == :bar
  end
end
