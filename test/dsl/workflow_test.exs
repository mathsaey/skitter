# Copyright 2018 - 2022, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.DSL.WorkflowTest do
  use ExUnit.Case, async: true

  import Skitter.DSL.Workflow, only: [workflow: 2, workflow: 1]
  import Skitter.DSL.Operation, only: [defoperation: 3]

  defoperation Example, in: in_port, out: out_port, strategy: DefaultStrategy do
  end

  defoperation Join, in: [left, right], out: _ do
  end

  defmodule MyCustomOperators do
    defmacro my_operator(opts \\ []) do
      quote do
        node(Example, unquote(opts))
      end
    end
  end

  doctest Skitter.DSL.Workflow

  test "name generation for embedded workflows" do
    wf =
      workflow do
        node(Example)

        node(
          workflow do
            node(Example)
          end
        )
      end

    assert Map.has_key?(wf.nodes, :"skitter/dsl/workflow_test/example#1")

    assert Map.has_key?(
             wf.nodes[:"#nested#1"].workflow.nodes,
             :"skitter/dsl/workflow_test/example#1"
           )
  end

  test "implicit in and out ports for nested workflows" do
    inner =
      workflow in: [one, two], out: [three, four] do
        one ~> three
        two ~> four
      end

    outer =
      workflow do
        node(Example)
        ~> node(inner)
        ~> node(Example)
      end

    n = outer.nodes

    assert n[:"skitter/dsl/workflow_test/example#1"].links == [out_port: ["#nested#1": :one]]
    assert n[:"#nested#1"].links == [three: ["skitter/dsl/workflow_test/example#2": :in_port]]
  end
end
