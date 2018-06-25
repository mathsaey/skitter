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

      create_checkpoint do
        nil
      end

      restore_checkpoint _ do
      end
    end

    assert EffectTest.__skitter_metadata__().effects
           |> Keyword.get(:state_change) == []

    assert EffectTest.__skitter_metadata__().effects
           |> Keyword.get(:external_effect) == []

    assert PropTest.__skitter_metadata__().effects
           |> Keyword.get(:state_change) == [:hidden]
  end

  test "if structs are generated correctly" do
    component WithStruct, in: foo do
      fields a, b, c

      react _ do
      end
    end

    defmodule Structs do
      assert Map.from_struct(%WithStruct{}) == %{a: nil, b: nil, c: nil}
      assert Map.from_struct(%WithStruct{a: 1}) == %{a: 1, b: nil, c: nil}
      assert Map.from_struct(%WithStruct{b: 2}) == %{a: nil, b: 2, c: nil}
    end
  end

  test "if init works" do
    component Init, in: [] do
      fields x, y

      init a do
        x <~ a
      end

      react do
      end
    end

    defmodule AssertInit do
      import Skitter.Component.Instance, only: [create: 2]

      assert Init.__skitter_init__(3) ==
               {:ok, create(Init, %Init{x: 3, y: nil})}
    end
  end

  test "if terminate works" do
    component TestTerminate, in: [] do
      fields a

      react do
      end

      terminate do
        send(self(), :hello)
      end
    end

    assert TestTerminate.__skitter_terminate__(nil) == :ok
    assert_received :hello
  end

  test "if react works" do
    component TestSpit, in: [foo], out: out do
      react foo do
        foo ~> out
      end
    end

    assert TestSpit.__skitter_react__(nil, [10]) == {:ok, nil, [out: 10]}
  end

  test "if state works correctly" do
    component Total, in: [foo] do
      effect state_change
      fields total

      init _ do
        total <~ 0
      end

      react val do
        total <~ (total + val)
      end
    end

    defmodule State do
      import Skitter.Component.Instance, only: [create: 2]
      {:ok, inst} = Total.__skitter_init__(nil)
      assert inst == create(Total, %Total{total: 0})
      {:ok, inst, []} = Total.__skitter_react__(inst, [5])
      assert inst == create(Total, %Total{total: 5})
      {:ok, inst, []} = Total.__skitter_react__(inst, [3])
      assert inst == create(Total, %Total{total: 8})
    end
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
        :foo ~> inner
        if bool, do: skip
        :foo ~> outer
      end
    end

    assert TestSkip.__skitter_react_after_failure__(nil, [true]) ==
             {:ok, nil, [inner: :foo]}

    assert TestSkip.__skitter_react_after_failure__(nil, [false]) ==
             {:ok, nil, [outer: :foo, inner: :foo]}
  end

  test "if create_checkpoint and restore_checkpoint work" do
    component CPTest, in: [] do
      effect state_change hidden
      fields a

      react do
      end

      init val do
        a <~ val
      end

      create_checkpoint do
        a
      end

      restore_checkpoint val do
        a <~ val
      end

      clean_checkpoint _ do
      end
    end

    assert {:ok, inst} = CPTest.__skitter_init__(:val)
    assert {:ok, chkp} = CPTest.__skitter_create_checkpoint__(inst)
    assert {:ok, rest} = CPTest.__skitter_restore_checkpoint__(chkp)

    assert inst == rest

    assert CPTest.__skitter_clean_checkpoint__(inst, chkp) == :ok
  end

  test "if defaults are generated correctly" do
    component TestGen, in: [] do
      react do
      end
    end

    defmodule TDefaults do
      import Skitter.Component.Instance, only: [create: 2]
      assert TestGen.__skitter_init__([]) == {:ok, create(TestGen, %TestGen{})}
      assert TestGen.__skitter_terminate__(nil) == :ok
      assert TestGen.__skitter_create_checkpoint__(nil) == :nocheckpoint
      assert TestGen.__skitter_restore_checkpoint__(nil) == :nocheckpoint
      assert TestGen.__skitter_clean_checkpoint__(nil, nil) == :nocheckpoint
    end
  end

  test "if helpers work" do
    component TestHelper, in: [], out: res do
      react do
        worker() ~> res
      end

      helper worker do
        :help
      end
    end

    assert TestHelper.__skitter_react__(nil, []) == {:ok, nil, [res: :help]}
  end

  test "if pattern matching works" do
    component Patterns, in: input, out: out do
      react :foo do
        :foo ~> out
      end

      react :bar do
        :bar ~> out
      end
    end

    assert Patterns.__skitter_react__(nil, [:foo]) == {:ok, nil, [out: :foo]}
    assert Patterns.__skitter_react__(nil, [:bar]) == {:ok, nil, [out: :bar]}
  end

  test "if errors work" do
    component ErrorsEverywhere, in: [] do
      init _ do
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

  test "if hygiene can be violated" do
    component Hygiene, in: [], out: p do
      @compile :nowarn_unused_vars

      react do
        5 ~> p
        output = :foo
      end
    end

    assert Hygiene.__skitter_react__(nil, []) == {:ok, nil, [p: 5]}
  end

  test "if a warning is shown when modifying names inside catch/if/..." do
    component CaseComp, in: val, out: [gt, lt] do
      react val do
        case val do
          x when x > 5 -> x ~> gt
          x when x < 5 -> x ~> lt
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

  test "if incorrect fields are reported" do
    assert_definition_error do
      component WrongFields, in: [] do
        fields :a, :b

        react do
        end
      end
    end

    assert_definition_error do
      component MultipleFields, in: [] do
        fields a
        fields b

        react _ do
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
        fields state

        react do
        end

        restore_checkpoint _ do
          state <~ nil
        end
      end
    end

    assert_definition_error do
      component MissingRestore, in: [] do
        effect state_change hidden

        react do
        end

        create_checkpoint do
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

  test "if incorrect use of create/restore _checkpoint is reported" do
    assert_definition_error do
      component WrongCheckpoint, in: [] do
        react do
        end

        create_checkpoint do
          nil
        end
      end
    end

    assert_definition_error do
      component WrongRestore, in: [] do
        fields state

        react do
        end

        restore_checkpoint _ do
          state <~ nil
        end
      end
    end
  end

  test "if incorrect use of `<~` is reported" do
    assert_definition_error do
      component WrongState, in: [] do
        fields state

        react do
          state <~ 30
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
          42 ~> :foo
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
          42 ~> bar
        end
      end
    end
  end
end
