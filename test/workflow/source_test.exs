defmodule Skitter.SourceTest do
  use ExUnit.Case, async: true

  import Skitter.Component

  alias Skitter.Workflow.Source
  alias Skitter.Component.Instance

  test "if metadata is generated correctly" do
    assert effects(Source) == []
    assert in_ports(Source) == [:__PRIVATE__]
    assert out_ports(Source) == [:data]
  end

  test "if init, react, and terminate work as they should" do
    {:ok, inst} = init(Source, nil)
    assert is_instance?(inst)
    assert :ok == terminate(inst)

    assert {:ok, %Instance{component: Source, state: []}, [data: 42]} ==
             react(inst, [42])

    assert {:ok, %Instance{component: Source, state: []}, [data: 42]} ==
             react_after_failure(inst, [42])
  end
end
