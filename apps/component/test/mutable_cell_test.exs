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

  test "if tables are converted to keyword lists correctly" do
    cell = create()

    assert to_keyword_list(cell) == []

    write(cell, :foo, 42)
    write(cell, :bar, "test")

    assert to_keyword_list(cell) == [foo: 42, bar: "test"]
  end
end
