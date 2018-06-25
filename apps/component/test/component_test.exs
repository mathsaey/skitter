defmodule Skitter.ComponentTest do
  use ExUnit.Case, async: true
  import Skitter.Component
  import Skitter.Component.Instance, only: [create: 2]

  doctest Skitter.Component

  component T1, in: [foo, bar], out: [foo, bar] do
    "Description"

    react _foo, _bar do
    end
  end

  component T2, in: [foo, bar] do
    effect state_change hidden
    effect external_effect

    fields f

    init _ do
      f <~ :init
    end

    react _foo, _bar do
    end

    create_checkpoint do
      :checkpoint
    end

    restore_checkpoint _ do
      f <~ :restore
    end
  end

  test "if fetching metadata works correctly" do
    refute is_component?(4)
    refute is_component?(X)
    refute is_component?(Enum)
    assert is_component?(T1)
    assert is_component?(T2)
    assert name(T1) == "T 1"
    assert description(T1) == "Description"
    assert in_ports(T1) == [:foo, :bar]
    assert out_ports(T1) == [:foo, :bar]
    assert state_change?(T1) == false
    assert external_effect?(T1) == false
    assert hidden_state_change?(T1) == false
    assert in_ports(T2) == [:foo, :bar]
    assert out_ports(T2) == []
    assert state_change?(T2) == true
    assert external_effect?(T2) == true
    assert hidden_state_change?(T2) == true
  end

  test "if callbacks work" do
    assert init(T2, nil) == {:ok, create(T2, %T2{f: :init})}
    assert terminate(T2, nil) == :ok
    assert create_checkpoint(T2, nil) == {:ok, :checkpoint}
    assert restore_checkpoint(T2, nil) == {:ok, create(T2, %T2{f: :restore})}
    assert clean_checkpoint(T2, nil, nil) == :ok
    assert react(T2, nil, [nil, nil]) == {:ok, nil, []}
    assert react_after_failure(T2, nil, [nil, nil]) == {:ok, nil, []}
  end
end
