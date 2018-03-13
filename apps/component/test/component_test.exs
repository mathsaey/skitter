defmodule Skitter.ComponentTest do
  use ExUnit.Case, async: true
  import Skitter.Component

  doctest Skitter.Component

  test "name generation" do
    defcomponent FOOBarBaz, :noeffects do
      @desc ""
      @in_ports []
      @out_ports []
    end

    defcomponent NameTest, :noeffects do
      @name "name changed"
      @desc ""
      @in_ports []
      @out_ports []
    end
    assert NameTest.name() == "name changed"
  end
end
