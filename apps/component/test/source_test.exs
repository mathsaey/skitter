defmodule Skitter.SourceTest do
  use ExUnit.Case, async: true

  import Skitter.Component
  alias Skitter.Source

  test "if metadata is generated correctly" do
    assert effects(Source) == []
    assert in_ports(Source) == [:__PRIVATE__]
    assert out_ports(Source) == [:data]
    assert in_ports_size(Source) == 1
  end

  test "if init, react, and terminate work as they should" do
    {:ok, inst} = init(Source, nil)
    assert is_instance?(inst)
    assert :ok == terminate(inst)

    assert {:ok, nil, [data: 42]} == react(inst, [42])
    assert {:ok, nil, [data: 42]} == react_after_failure(inst, [42])
  end

  test "if checkpoint functions are properly disabled" do
    {:ok, inst} = init(Source, nil)
    assert :nocheckpoint == create_checkpoint(inst)
    assert :nocheckpoint == clean_checkpoint(inst, nil)
    assert :nocheckpoint == clean_checkpoint(inst, nil)
  end
end
