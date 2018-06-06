defmodule Skitter.ComponentDSLTest do
  use ExUnit.Case, async: true
  import Skitter.Component.DSL

  # ---------------- #
  # Extra Assertions #
  # ---------------- #

  defmacro assert_definition_error(do: body) do
    quote do
      assert_raise Skitter.Component.DefinitionError, fn -> unquote(body) end
    end
  end

  # ----- #
  # Tests #
  # ----- #

  doctest Skitter.Component.DSL

  test "if names are generated correctly" do
    component Dot.In.Name, in: [] do
      react do
      end
    end

    component SimpleName, in: [] do
      react do
      end
    end

    component ACRTestACR, in: [] do
      react do
      end
    end

    component Numbers123F, in: [] do
      react do
      end
    end

    assert Dot.In.Name.__skitter_metadata__().name == "Name"
    assert SimpleName.__skitter_metadata__().name == "Simple Name"
    assert ACRTestACR.__skitter_metadata__().name == "ACR Test ACR"
    assert Numbers123F.__skitter_metadata__().name == "Numbers 123 F"
  end

  test "if descriptions work as they should" do
    component EmptyD, in: [] do
      react do
      end
    end

    component NormalD, in: [] do
      "Description"

      react do
      end
    end

    component MultilineD, in: [] do
      """
      D
      """

      react do
      end
    end

    assert EmptyD.__skitter_metadata__().description == ""
    assert NormalD.__skitter_metadata__().description == "Description"
    assert String.trim(MultilineD.__skitter_metadata__().description) == "D"
  end

  test "If correct ports are accepted" do
    # Should not raise
    component CorrectPorts, in: [foo, bar], out: test do
      react _foo, _bar do
      end
    end
  end

  test "if effects are parsed correctly" do
    component EffectTest, in: [] do
      effect state_change
      effect external_effect

      react do
      end
    end

    component PropTest, in: [] do
      effect state_change hidden

      react do
      end

      checkpoint do
        checkpoint!(nil)
      end

      restore _ do
        instance! nil
      end
    end

    assert EffectTest.__skitter_metadata__().effects
           |> Keyword.get(:state_change) == []

    assert EffectTest.__skitter_metadata__().effects
           |> Keyword.get(:external_effect) == []

    assert PropTest.__skitter_metadata__().effects
           |> Keyword.get(:state_change) == [:hidden]
  end

  test "if init works" do
    component TestInit, in: [] do
      init {a, b} do
        instance! a * b
      end

      react do
      end
    end

    assert TestInit.__skitter_init__({3, 4}) == {:ok, 3 * 4}
  end

  test "if terminate works" do
    component TestTerminateNoInst, in: [] do
      react do
      end

      terminate do
      end
    end

    component TestTerminateInst, in: [] do
      react do
      end

      terminate do
        send(self(), instance)
      end
    end

    assert TestTerminateNoInst.__skitter_terminate__(:not_used) == :ok
    assert TestTerminateInst.__skitter_terminate__(:used) == :ok
    assert_received :used
  end

  test "if checkpoint and restore work" do
    component CPTest, in: [] do
      effect state_change hidden

      react do
      end

      init val do
        instance! val
      end

      checkpoint do
        checkpoint!(instance)
      end

      restore val do
        instance! val
      end

      clean_checkpoint _ do
      end
    end

    {:ok, inst} = CPTest.__skitter_init__(:val)
    {:ok, chkp} = CPTest.__skitter_checkpoint__(inst)
    {:ok, rest} = CPTest.__skitter_restore__(chkp)

    assert chkp == :val
    assert rest == :val

    assert CPTest.__skitter_clean_checkpoint__(chkp) == :ok
  end

  test "if defaults are generated correctly" do
    component TestGenerated, in: [] do
      react do
      end
    end

    assert TestGenerated.__skitter_init__([]) == {:ok, nil}
    assert TestGenerated.__skitter_terminate__(nil) == :ok
    assert TestGenerated.__skitter_checkpoint__(nil) == :nocheckpoint
    assert TestGenerated.__skitter_restore__(nil) == :nocheckpoint
    assert TestGenerated.__skitter_clean_checkpoint__(nil) == :nocheckpoint
  end

  test "if helpers work" do
    component TestHelper, in: [] do
      init _ do
        instance! worker()
      end

      helper worker do
        :from_helper
      end

      react do
      end
    end

    assert TestHelper.__skitter_init__([]) == {:ok, :from_helper}
  end

  test "if react works" do
    component TestSpit, in: [foo], out: out do
      react foo do
        spit foo ~> out
      end
    end

    assert TestSpit.__skitter_react__(nil, [10]) == {:ok, nil, [out: 10]}
  end

  test "if pattern matching works" do
    component Patterns, in: input, out: out do
      init :foo do
        instance! :foo
      end

      init :bar do
        instance! :bar
      end

      react :foo do
        spit :foo ~> out
      end

      react :bar do
        spit :bar ~> out
      end
    end

    assert Patterns.__skitter_init__(:foo) == {:ok, :foo}
    assert Patterns.__skitter_init__(:bar) == {:ok, :bar}
    assert Patterns.__skitter_react__(nil, [:foo]) == {:ok, nil, [out: :foo]}
    assert Patterns.__skitter_react__(nil, [:bar]) == {:ok, nil, [out: :bar]}
  end

  test "if instances work correctly" do
    component TestInstance, in: [foo] do
      effect state_change

      init arg do
        instance! arg
      end

      react foo do
        new = instance + foo
        instance! new
      end
    end

    {:ok, inst} = TestInstance.__skitter_init__(10)
    assert inst == 10

    {:ok, inst, []} = TestInstance.__skitter_react__(inst, [5])
    assert inst == 15
  end

  test "if after_failure works as it should" do
    component TestAfterFailure, in: [] do
      effect external_effect

      react do
        after_failure do
          raise "some error"
        end
      end
    end

    # should not raise
    TestAfterFailure.__skitter_react__(nil, [])

    assert_raise RuntimeError, fn ->
      TestAfterFailure.__skitter_react_after_failure__(nil, [])
    end
  end

  test "if spit works" do
    component TestSkip, in: [bool], out: [inner, outer] do
      react bool do
        spit :foo ~> inner
        if bool, do: skip
        spit :foo ~> outer
      end
    end

    assert TestSkip.__skitter_react_after_failure__(nil, [true]) ==
             {:ok, nil, [inner: :foo]}

    assert TestSkip.__skitter_react_after_failure__(nil, [false]) ==
             {:ok, nil, [outer: :foo, inner: :foo]}
  end

  test "if errors work" do
    component ErrorsEverywhere, in: [] do
      init _ do
        instance! :not_used
        error "error!"
      end

      react do
        error "error!"
      end

      terminate do
        error "error!"
      end
    end

    assert ErrorsEverywhere.__skitter_init__([]) == {:error, "error!"}
    assert ErrorsEverywhere.__skitter_react__(nil, []) == {:error, "error!"}
    assert ErrorsEverywhere.__skitter_terminate__(nil) == {:error, "error!"}
  end

  test "if a warning is shown when modifying names inside catch/if/..." do
    component CaseComp, in: val, out: [gt, lt] do
      react val do
        case val do
          x when x > 5 -> spit x ~> gt
          x when x < 5 -> spit x ~> lt
        end
      end
    end
  end

  # Error Reporting
  # ---------------

  test "if incorrect effects are reported" do
    assert_definition_error do
      component WrongEffects, in: [] do
        effect does_not_exist

        react do
        end
      end
    end
  end

  test "if a missing react is reported" do
    assert_definition_error do
      component MissingReact, in: [] do
        # No react should cause an error
      end
    end
  end

  test "if missing checkpoints are reported" do
    assert_definition_error do
      component MissingCheckpoint, in: [] do
        effect state_change hidden

        react do
        end

        restore _ do
          instance! nil
        end
      end
    end

    assert_definition_error do
      component MissingRestore, in: [] do
        effect state_change hidden

        react do
        end

        checkpoint do
          checkpoint!(nil)
        end
      end
    end
  end

  test "if incorrect effect properties are reported" do
    assert_definition_error do
      component WrongPropertySyntax, in: [] do
        effect state_change 5

        react do
        end
      end
    end

    assert_definition_error do
      component WrongEffectProperties, in: [] do
        effect state_change foo

        react do
        end
      end
    end
  end

  test "if incorrect use of react after_failure is reported" do
    assert_definition_error do
      component WrongAfterFailure, in: [val] do
        react val do
          after_failure do
          end
        end
      end
    end
  end

  test "if a useless init is reported" do
    assert_definition_error do
      component UselessInit, in: [] do
        init _ do
          :does_nothing
        end

        react do
        end
      end
    end
  end

  test "if a useless checkpoint/restore is reported" do
    assert_definition_error do
      component UselessCheckpoint, in: [] do
        effect state_change hidden

        react do
        end

        checkpoint do
        end

        restore _ do
          instance! nil
        end
      end
    end

    assert_definition_error do
      component UselessRestore, in: [] do
        effect state_change hidden

        react do
        end

        checkpoint do
          checkpoint!(nil)
        end

        restore _ do
          nil
        end
      end
    end
  end

  test "if incorrect use of checkpoint/restore is reported" do
    assert_definition_error do
      component WrongCheckpoint, in: [] do
        react do
        end

        checkpoint do
          checkpoint!(nil)
        end
      end
    end

    assert_definition_error do
      component WrongRestore, in: [] do
        react do
        end

        restore _ do
          instance! nil
        end
      end
    end
  end

  test "if incorrect instance! use is reported" do
    assert_definition_error do
      component WrongInstance, in: [] do
        react do
          instance! 30
        end
      end
    end
  end

  test "if incorrectly named ports are reported" do
    assert_definition_error do
      component SymbolPorts, in: [:foo, :bar] do
      end
    end

    assert_definition_error do
      component SymbolInSpit, in: [], out: [:foo] do
        react do
          spit(42) ~> :foo
        end
      end
    end
  end

  test "if a wrong react signature is reported" do
    assert_definition_error do
      component WrongInPorts, in: [:a, :b, :c] do
        react a, b do
        end
      end
    end
  end

  test "if incorrect port use in react is reported" do
    assert_definition_error do
      component WrongSpit, in: [], out: [:foo] do
        react do
          spit 42 ~> bar
        end
      end
    end
  end
end
