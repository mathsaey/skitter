defmodule Skitter.Internal.MutableCellTest do
  use ExUnit.Case, async: true

  import Skitter.Internal.MutableCell

  test "if creation, reading, and writing works" do
    cell = create()
    write(cell, :foo, 42)
    assert read(cell, :foo) == 42
  end

  test "if tables are destroyed correctly" do
    cell = create()
    write(cell, :foo, 42)
    destroy(cell)

    assert catch_error(read(cell, :foo))
  end
end
