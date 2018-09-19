# Copyright 2018, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Component.DSLTest do
  use ExUnit.Case, async: true

  import Skitter.Assertions
  import Skitter.Component.DSL

  alias Skitter.Component.Instance

  # ---------------- #
  # Extra Assertions #
  # ---------------- #

  # Needed to compare instances with a non-trivial state
  defp assert_instance_equals(
         %Instance{component: c1, state: s1},
         %Instance{component: c2, state: s2}
       ) do
    assert c1 == c2
    assert Keyword.equal?(s1, s2)
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

      clean_checkpoint _ do
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

  test "if init works" do
    component Init, in: [] do
      fields x, y

      init a do
        x <~ a
      end

      react do
      end
    end

    {:ok, inst} = Init.__skitter_init__(3)

    assert_instance_equals(
      inst,
      %Instance{component: Init, state: [x: 3, y: nil]}
    )
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

    {:ok, inst} = Total.__skitter_init__(nil)
    assert inst == %Instance{component: Total, state: [total: 0]}
    {:ok, inst, []} = Total.__skitter_react__(inst, [5])
    assert inst == %Instance{component: Total, state: [total: 5]}
    {:ok, inst, []} = Total.__skitter_react__(inst, [3])
    assert inst == %Instance{component: Total, state: [total: 8]}
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

  test "if skip works" do
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

  test "if create_checkpoint, clean_checkpoint and restore_checkpoint work" do
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

    {:ok, inst} = TestGen.__skitter_init__([])

    assert inst == %Instance{component: TestGen, state: []}
    assert TestGen.__skitter_terminate__(inst) == :ok
    assert TestGen.__skitter_create_checkpoint__(inst) == {:ok, []}
    assert TestGen.__skitter_restore_checkpoint__([]) == {:ok, inst}
    assert TestGen.__skitter_clean_checkpoint__(nil, nil) == :ok
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
      effect state_change hidden

      init _ do
        error "error!"
      end

      react do
        error "error!"
      end

      terminate do
        error "error!"
      end

      create_checkpoint do
        error "error!"
      end

      restore_checkpoint _ do
        error "error!"
      end

      clean_checkpoint _ do
        error "error!"
      end
    end

    assert ErrorsEverywhere.__skitter_init__([]) == {:error, "error!"}
    assert ErrorsEverywhere.__skitter_react__(nil, []) == {:error, "error!"}
    assert ErrorsEverywhere.__skitter_terminate__(nil) == {:error, "error!"}

    assert ErrorsEverywhere.__skitter_create_checkpoint__(nil) ==
             {:error, "error!"}

    assert ErrorsEverywhere.__skitter_restore_checkpoint__(nil) ==
             {:error, "error!"}

    assert ErrorsEverywhere.__skitter_clean_checkpoint__(nil, nil) ==
             {:error, "error!"}
  end

  test "if hygiene can be violated" do
    component Hygiene, in: [], out: p do
      react do
        5 ~> p
        output = :foo
        # Suppress unused variables warning
        _ = output
      end
    end

    assert Hygiene.__skitter_react__(nil, []) == {:ok, nil, [p: 5]}
  end

  test "If imperative spiting/updating is possible" do
    component CaseSpit, in: val, out: [gt, lt] do
      react val do
        case val do
          x when x > 5 -> x ~> gt
          x when x < 5 -> x ~> lt
        end
      end
    end

    assert CaseSpit.__skitter_react__(nil, [10]) == {:ok, nil, [gt: 10]}

    component CaseState, in: val do
      effect state_change
      fields my_field

      init _ do
        my_field <~ nil
      end

      react val do
        case val do
          :update ->
            my_field <~ val

          _ ->
            nil
        end
      end
    end

    {:ok, inst} = CaseState.__skitter_init__(nil)
    assert CaseState.__skitter_react__(inst, [:foo]) == {:ok, inst, []}

    assert CaseState.__skitter_react__(inst, [:update]) == {
             :ok,
             %Instance{component: CaseState, state: [my_field: :update]},
             []
           }
  end

  # Error Reporting
  # ---------------

  test "if incorrect effects are reported" do
    assert_definition_error ~r/Effect .* is not valid/ do
      component WrongEffects, in: [] do
        effect does_not_exist

        react do
        end
      end
    end
  end

  test "if incorrect fields are reported" do
    assert_definition_error ~r/.* is not a valid field/ do
      component WrongFields, in: [] do
        fields :a, :b

        react do
        end
      end
    end

    assert_definition_error "Fields can only be defined once" do
      component MultipleFields, in: [] do
        fields a
        fields b

        react _ do
        end
      end
    end
  end

  test "if a missing react is reported" do
    assert_definition_error "Missing react implementation" do
      component MissingReact, in: [] do
        # No react should cause an error
      end
    end
  end

  test "if missing checkpoints are reported" do
    assert_definition_error ~r/.* required when the state change is hidden/ do
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

    assert_definition_error ~r/.* required when the state change is hidden/ do
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
    assert_definition_error ~r/.* is not a valid property/ do
      component WrongPropertySyntax, in: [] do
        effect state_change 5

        react do
        end
      end
    end

    assert_definition_error ~r/.* is not a valid property of .*/ do
      component WrongEffectProperties, in: [] do
        effect state_change foo

        react do
        end
      end
    end
  end

  test "if incorrect use of react after_failure is reported" do
    assert_definition_error ~r/.* allowed when external_effect is present/ do
      component WrongAfterFailure, in: [val] do
        react val do
          after_failure do
          end
        end
      end
    end
  end

  test "if incorrect use of create/restore _checkpoint is reported" do
    assert_definition_error ~r/.* allowed when the state change is hidden/ do
      component WrongCheckpoint, in: [] do
        react do
        end

        create_checkpoint do
          nil
        end
      end
    end

    assert_definition_error ~r/.* allowed when the state change is hidden/ do
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

  test "if incorrect uses of `<~` are reported" do
    assert_definition_error "`<~` can not be used in this context" do
      component MutableTerminate, in: [] do
        fields state

        react do
        end

        terminate do
          state <~ 5
        end
      end
    end

    assert_definition_error "`<~` can not be used in this context" do
      component MutableCheckpoint1, in: [] do
        effect state_change hidden
        fields state

        react do
        end

        create_checkpoint do
          state <~ 5
        end

        restore_checkpoint _ do
        end

        clean_checkpoint _ do
        end
      end
    end

    assert_definition_error "`<~` can not be used in this context" do
      component MutableCheckpoint2, in: [] do
        effect state_change hidden
        fields state

        react do
        end

        create_checkpoint do
          5
        end

        restore_checkpoint _ do
        end

        clean_checkpoint _ do
          state <~ 5
        end
      end
    end

    assert_definition_error ~r/.* when the state_change effect is present/ do
      component ImmutableState, in: [] do
        fields state

        react do
          state <~ 30
        end
      end
    end
  end

  test "if incorrectly named ports are reported" do
    assert_definition_error ~r/.* is not a valid port/ do
      component SymbolPorts, in: [:foo, :bar] do
      end
    end

    assert_definition_error ~r/.* is not a valid port/ do
      component SymbolInSpit, in: [], out: [:foo] do
        react do
          42 ~> :foo
        end
      end
    end
  end

  test "if a wrong react signature is reported" do
    assert_definition_error "Different amount of arguments and in_ports" do
      component WrongInPorts, in: [a, b, c] do
        react a, b do
        end
      end
    end
  end

  test "if incorrect port use in react is reported" do
    assert_definition_error ~r/.* not in out_ports/ do
      component WrongSpit, in: [], out: [foo] do
        react do
          42 ~> bar
        end
      end
    end
  end
end
