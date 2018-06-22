defmodule Skitter.ComponentTest do
  use ExUnit.Case, async: true
  import Skitter.Component

  doctest Skitter.Component

  component TestComponent1, in: [foo, bar], out: [foo, bar] do
    "Description"

    react _foo, _bar do
    end
  end

  component TestComponent2, in: [foo, bar] do
    effect state_change hidden
    effect external_effect

    init _ do
      state = :init_works
    end

    react _foo, _bar do
    end

    checkpoint do
      checkpoint = :checkpoint_works
    end

    restore _ do
      state = :restore_works
    end
  end

  test "if fetching metadata works correctly" do
    assert name(TestComponent1) == "Test Component 1"
    assert description(TestComponent1) == "Description"
    assert in_ports(TestComponent1) == [:foo, :bar]
    assert out_ports(TestComponent1) == [:foo, :bar]
    assert state_change?(TestComponent1) == false
    assert external_effect?(TestComponent1) == false
    assert hidden_state_change?(TestComponent1) == false
    assert in_ports(TestComponent2) == [:foo, :bar]
    assert out_ports(TestComponent2) == []
    assert state_change?(TestComponent2) == true
    assert external_effect?(TestComponent2) == true
    assert hidden_state_change?(TestComponent2) == true
  end

  test "if callbacks work" do
    assert init(TestComponent2, nil) == {:ok, :init_works}
    assert terminate(TestComponent2, nil) == :ok
    assert checkpoint(TestComponent2, nil) == {:ok, :checkpoint_works}
    assert restore(TestComponent2, nil) == {:ok, :restore_works}
    assert clean_checkpoint(TestComponent2, nil, nil) == :ok
    assert react(TestComponent2, nil, [nil, nil]) == {:ok, nil, []}

    assert react_after_failure(TestComponent2, nil, [nil, nil]) ==
             {:ok, nil, []}
  end
end
