defmodule WorkflowTest do
  use ExUnit.Case
  doctest Workflow

  test "greets the world" do
    assert Workflow.hello() == :world
  end
end
