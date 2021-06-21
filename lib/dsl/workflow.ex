# Copyright 2018 - 2021, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.DSL.Workflow do
  @moduledoc """
  Workflow definition DSL.

  This module offers a macro to define workflow. To define a workflow, use `workflow/2`. Inside
  the body of the workflow, `node/2` and `~>/2` can be used. Unlike
  `Skitter.DSL.Component.defcomponent/3` and `Skitter.DSL.Strategy.defstrategy/3`, the
  `workflow/2` macro does not generate a module, instead, it generates a `t:Skitter.Workflow.t/0`.
  """

  alias Skitter.{DSL.AST, Component, Workflow}

  # -------- #
  # Workflow #
  # -------- #

  @doc """
  Define a workflow.

  This macro generates a `t:Skitter.Workflow.t/0`. Inside the body of this macro, `node/2` and
  `~>/2` can be used to define nodes and links between nodes, respectively. The generated workflow
  is verified after its definition through the use of `Skitter.Workflow.verify/1`.

  ## Workflow ports

  The ports of a workflow can be defined in the header of the workflow macro as follows:

      iex> wf = workflow in: [a], out: [x] do
      ...> end
      iex> wf.in
      [a: []]
      iex> wf.out
      [:x]

  If a workflow has no `in`, or `out` ports, they can be omitted from the workflow header.
  Furthermore, if the workflow only has a single `in` or `out` port, the list notation can be
  omitted:

      iex> wf = workflow in: a do
      ...> end
      iex> wf.in
      [a: []]
      iex> wf.out
      []

  ## Nodes, links and syntactic sugar

  Inside the body of a workflow, the `node/2` and `~>/2` macros are used to define nodes and to
  link them to one another:

      iex> wf = workflow do
      ...>   node Example, as: node1
      ...>   node Example, as: node2
      ...>
      ...>   node1.out_port ~> node2.in_port
      ...> end
      iex> wf.nodes[:node1].component
      Example
      iex> wf.nodes[:node1].links
      [out_port: [node2: :in_port]]

  To link nodes to the in or out ports of a workflow, the port name should be used:

      iex> wf = workflow in: foo, out: bar do
      ...>   node Example, as: node
      ...>
      ...>   foo ~> node.in_port
      ...>   node.out_port ~> bar
      ...> end
      iex> wf.nodes[:node].links
      [out_port: [:bar]]
      iex> wf.in
      [foo: [node: :in_port]]

  Previously defined workflows may be used inside a workflow definition:

      iex> inner = workflow in: foo, out: bar do
      ...>   node Example, as: node
      ...>
      ...>   foo ~> node.in_port
      ...>   node.out_port ~> bar
      ...> end
      iex> outer = workflow do
      ...>   node inner, as: inner_left
      ...>   node inner, as: inner_right
      ...>
      ...>   inner_left.bar ~> inner_right.foo
      ...> end
      iex> outer.nodes[:inner_left].workflow == inner
      true
      iex> outer.nodes[:inner_left].links
      [bar: [inner_right: :foo]]

  Instead of specifying the complete source name (e.g. `node.in_port`), the following syntactic
  sugar can be used when creating a node:

      iex> wf = workflow in: foo do
      ...>   foo ~> node(Example, as: node)
      ...> end
      iex> wf.in
      [foo: [node: :in_port]]

      iex> wf = workflow out: bar do
      ...>   node(Example, as: node) ~> bar
      ...> end
      iex> wf.nodes[:node].links
      [out_port: [:bar]]

  These uses of `~>/2` can be chained:

      iex> wf = workflow in: foo, out: bar do
      ...>   foo
      ...>   ~> node(Example, as: node1)
      ...>   ~> node(Example, as: node2)
      ...>   ~> bar
      ...> end
      iex> wf.in
      [foo: [node1: :in_port]]
      iex> wf.nodes[:node1].links
      [out_port: [node2: :in_port]]
      iex> wf.nodes[:node2].links
      [out_port: [:bar]]

  It is not needed to explicitly specify a name for a node if you do not need to refer to the
  node. You should not rely on the format of the generated names in this case:

      iex> wf = workflow in: foo, out: bar do
      ...>   foo
      ...>   ~> node(Example)
      ...>   ~> node(Example)
      ...>   ~> bar
      ...> end
      iex> wf.in
      [foo: ["skitter/dsl/workflow_test/example#1": :in_port]]
      iex> wf.nodes[:"skitter/dsl/workflow_test/example#1"].links
      [out_port: ["skitter/dsl/workflow_test/example#2": :in_port]]
      iex> wf.nodes[:"skitter/dsl/workflow_test/example#2"].links
      [out_port: [:bar]]

  ## Examples

      iex> workflow in: [foo, bar], out: baz do
      ...>   foo ~> node(Example) ~> joiner.left
      ...>   bar ~> node(Example) ~> joiner.right
      ...>
      ...>   node(Join, with: SomeStrategy, as: joiner)
      ...>   ~> node(Example, args: :some_args)
      ...>   ~> baz
      ...> end
      %Skitter.Workflow{
        in: [
          foo: ["skitter/dsl/workflow_test/example#1": :in_port],
          bar: ["skitter/dsl/workflow_test/example#2": :in_port],
        ],
        out: [:baz],
        nodes: %{
          "skitter/dsl/workflow_test/example#1": %Skitter.Workflow.Node.Component{
            component: Example, args: nil, strategy: DefaultStrategy, links: [out_port: [joiner: :left]]
          },
          "skitter/dsl/workflow_test/example#2": %Skitter.Workflow.Node.Component{
            component: Example, args: nil, strategy: DefaultStrategy, links: [out_port: [joiner: :right]]
          },
          joiner: %Skitter.Workflow.Node.Component{
            component: Join, args: nil, strategy: SomeStrategy, links: [_: ["skitter/dsl/workflow_test/example#3": :in_port]]
          },
          "skitter/dsl/workflow_test/example#3": %Skitter.Workflow.Node.Component{
            component: Example, args: :some_args, strategy: DefaultStrategy, links: [out_port: [:baz]]
          }
        }
      }

  """
  defmacro workflow(opts \\ [], do: body) do
    in_ = opts |> Keyword.get(:in, []) |> AST.names_to_atoms()
    out = opts |> Keyword.get(:out, []) |> AST.names_to_atoms()

    quote do
      import Kernel, except: [node: 1]
      import unquote(__MODULE__), only: [node: 1, node: 2, ~>: 2, workflow: 2, workflow: 1]

      unquote(__MODULE__)._gen_name_state_init()

      unquote(node_var()) = %{}
      unquote(link_var()) = []

      unquote(body)

      unquote(__MODULE__)._gen_name_state_clean()

      {nodes, in_} =
        unquote(__MODULE__)._merge_links(unquote(link_var()), unquote(node_var()), unquote(in_))

      %Skitter.Workflow{
        in: in_,
        out: unquote(out),
        nodes: nodes
      }
      |> Skitter.Workflow.verify!()
    end
  end

  defp node_var(), do: quote(do: var!(nodes, unquote(__MODULE__)))
  defp link_var(), do: quote(do: var!(links, unquote(__MODULE__)))

  # ----- #
  # Nodes #
  # ----- #

  alias Skitter.Workflow.Node.Component, as: C
  alias Skitter.Workflow.Node.Workflow, as: W

  @doc """
  Generate a single workflow node.

  This macro generates a single node of a workflow. It can only be used inside `workflow/2`. It
  accepts a `t:Skitter.Component.t/0` or a workflow `t:Skitter.Workflow.t/0` and a list of
  optional options. The provided component or workflow will be wrapped inside a
  `t:Skitter.Workflow.component/0` or `t:Skitter.Workflow.workflow/0`. No links will be added to
  the generated node.

  Two options can be passed when creating a node: `as:` and `args:`:

  - `as:` defines the name of the node inside the workflow. It can be used to refer to the
  component when creating links with `~>/2`. If no name is specified, this macro will generate a
  name.
  - `args:` defines the arguments to pass to the node. Note that this is only relevant for
  component nodes. Arguments passed to workflow nodes are ignored. If no arguments are provided,
  the arguments of the node defaults to `nil`.
  - `with:` defines the strategy to pass to the node. Note that this is only relevant for
  component nodes. When a strategy is provided here, it will override the one defined by the
  component. If no strategy is provided, the strategy specified by the component will be used. If
  no strategy is specified by the component, an error will be raised.

  ## Examples

      iex> inner = workflow do
      ...>   node Example
      ...>   node Example, as: example_1
      ...>   node Example, args: :args
      ...>   node Example, as: example_2, args: :args, with: SomeStrategy
      ...> end
      %Skitter.Workflow{
        in: [],
        out: [],
        nodes: %{
          "skitter/dsl/workflow_test/example#1": %Skitter.Workflow.Node.Component{
            component: Example, args: nil, strategy: DefaultStrategy, links: []
          },
          example_1:  %Skitter.Workflow.Node.Component{
            component: Example, args: nil, strategy: DefaultStrategy, links: []
          },
          "skitter/dsl/workflow_test/example#2": %Skitter.Workflow.Node.Component{
            component: Example, args: :args, strategy: DefaultStrategy, links: []
          },
          example_2:  %Skitter.Workflow.Node.Component{
            component: Example, args: :args, strategy: SomeStrategy, links: []
          },
        }
      }
      iex> workflow do
      ...>   node inner
      ...>   node inner, as: nested_1
      ...>   node inner, args: :will_be_ignored, as: nested_2
      ...> end
      %Skitter.Workflow{
        in: [],
        out: [],
        nodes: %{
          "#nested#1": %Skitter.Workflow.Node.Workflow{workflow: inner, links: []},
          nested_1: %Skitter.Workflow.Node.Workflow{workflow: inner, links: []},
          nested_2: %Skitter.Workflow.Node.Workflow{workflow: inner, links: []}
        }
      }

      iex> workflow do
      ...>   node Join
      ...> end
      ** (Skitter.DefinitionError) Component Elixir.Skitter.DSL.WorkflowTest.Join does not define a strategy and no strategy was specified by the workflow

      iex> workflow do
      ...>   node Join, with: SomeStrategy
      ...> end
      %Skitter.Workflow{
        in: [],
        out: [],
        nodes: %{
          "skitter/dsl/workflow_test/join#1": %Skitter.Workflow.Node.Component{
            component: Join, args: nil, strategy: SomeStrategy, links: []
          }
        }
      }
  """
  defmacro node(comp_or_wf, opts \\ []) do
    name =
      case Keyword.get(opts, :as) do
        {name, _, _} -> name
        nil -> quote(do: unquote(__MODULE__)._gen_name(node))
      end

    args = Keyword.get(opts, :args)
    strat = Keyword.get(opts, :with)

    quote do
      node = unquote(comp_or_wf)
      name = unquote(name)
      node = unquote(__MODULE__)._make_node(unquote(comp_or_wf), unquote(args), unquote(strat))
      unquote(node_var()) = Map.put(unquote(node_var()), name, node)
      {name, node}
    end
  end

  # Name Generation
  # ---------------

  def _gen_name_state_init do
    case Process.get(:sk_name_gen) do
      nil -> Process.put(:sk_name_gen, [%{}])
      lst -> Process.put(:sk_name_gen, [%{} | lst])
    end
  end

  def _gen_name_state_clean do
    case Process.get(:sk_name_gen) do
      [_] -> Process.delete(:sk_name_gen)
      [_ | rest] -> Process.put(:sk_name_gen, rest)
    end
  end

  def _gen_name(atom) when is_atom(atom), do: atom |> Macro.underscore() |> gen_name()
  def _gen_name(%Workflow{}), do: gen_name("#nested")

  defp gen_name(str) do
    [names | rest] = Process.get(:sk_name_gen)

    {ctr, map} =
      Map.get_and_update(names, str, fn
        nil -> {1, 2}
        ctr -> {ctr, ctr + 1}
      end)

    Process.put(:sk_name_gen, [map | rest])
    String.to_atom("#{str}##{ctr}")
  end

  # ----- #
  # Links #
  # ----- #

  @doc """
  Generate a workflow link.

  This macro connects two ports in the workflow with each other. It can only be used inside
  `workflow/2`.

  This macro can be used in various different ways and provides various conveniences to shorten
  the definition of a workflow. In its most basic form, this macro is used as follows:

  ```
  source ~> destination
  ```

  Where source and destination have one of the following two forms:

  * `<component name>.<port name>`: specifies a component port
  * `<port name>`: specifies a workflow port

  For instance:

      iex> wf = workflow in: foo, out: bar do
      ...>   node Example, as: node1
      ...>   node Example, as: node2
      ...>
      ...>   foo ~> node1.in_port            # workflow port ~> component port
      ...>   node1.out_port ~> node2.in_port # component port ~> component port
      ...>   node2.out_port ~> bar           # component port ~> workflow port
      ...> end
      iex> wf.in
      [foo: [node1: :in_port]]
      iex> wf.nodes[:node1].links
      [out_port: [node2: :in_port]]
      iex> wf.nodes[:node2].links
      [out_port: [:bar]]

  Some syntactic sugar is present for linking nodes when they are created:

  * When the left hand side of `~>` is a node, a link is created between the first out port of
  this node and the destination.
  * When the right hand side of `~>` is a node, a link is created between the source and the first
  in port of this node.

  For instance:

      iex> wf = workflow in: foo, out: bar do
      ...>   foo ~> node(Example, as: node1)
      ...>   node(Example, as: node2) ~> bar
      ...> end
      iex> wf.in
      [foo: [node1: :in_port]]
      iex> wf.nodes[:node1].links
      []
      iex> wf.nodes[:node2].links
      [out_port: [:bar]]

  Both the left hand side and the right hand side can be nodes:

      iex> wf = workflow do
      ...>   node(Example, as: node1) ~> node(Example, as: node2)
      ...> end
      iex> wf.nodes[:node1].links
      [out_port: [node2: :in_port]]

  Finally, `~>` always returns the right hand side as its result. This enables `~>` to be chained.

      iex> wf = workflow in: foo, out: bar do
      ...>   foo ~> node(Example, as: node1) ~> node(Example, as: node2) ~> bar
      ...> end
      iex> wf.in
      [foo: [node1: :in_port]]
      iex> wf.nodes[:node1].links
      [out_port: [node2: :in_port]]
      iex> wf.nodes[:node2].links
      [out_port: [:bar]]

  """
  defmacro left ~> right do
    left = maybe_transform_ast(left)
    right = maybe_transform_ast(right)

    quote do
      left = unquote(left)
      right = unquote(right)
      unquote(link_var()) = [unquote(__MODULE__)._make_link(left, right) | unquote(link_var())]
      right
    end
  end

  defp maybe_transform_ast({{:., _, [{n, _, _}, p]}, _, _}), do: {n, p} |> Macro.escape()
  defp maybe_transform_ast({name, _, rhs}) when is_atom(name) and is_atom(rhs), do: name
  defp maybe_transform_ast(any), do: any

  def _make_node(m, a, nil) when is_atom(m) do
    case Component.strategy(m) do
      nil ->
        raise(
          Skitter.DefinitionError,
          "Component #{m} does not define a strategy and no strategy was specified by the workflow"
        )

      s ->
        _make_node(m, a, s)
    end
  end

  def _make_node(m, a, s) when is_atom(m), do: %C{component: m, args: a, strategy: s}

  def _make_node(wf = %Workflow{}, _, _), do: %W{workflow: wf}

  def _make_link({ln, ls}, {rn, rs}) when is_struct(ls) and is_struct(rs) do
    {{ln, implicit_out_port(ls)}, {rn, implicit_in_port(rs)}}
  end

  def _make_link(src, {rn, rs}) when is_struct(rs), do: {src, {rn, implicit_in_port(rs)}}
  def _make_link({ln, ls}, dst) when is_struct(ls), do: {{ln, implicit_out_port(ls)}, dst}
  def _make_link(src, dst), do: {src, dst}

  defp implicit_in_port(%W{workflow: %Workflow{in: [p | _]}}), do: p
  defp implicit_in_port(%C{component: comp}), do: comp |> Component.in_ports() |> hd()

  defp implicit_out_port(%W{workflow: %Workflow{out: [p | _]}}), do: p
  defp implicit_out_port(%C{component: comp}), do: comp |> Component.out_ports() |> hd()

  def _merge_links(links, nodes, in_ports) do
    in_ports = Enum.map(in_ports, &{&1, []})
    Enum.reduce(links, {nodes, in_ports}, &merge/2)
  end

  defp merge({{name, port}, dst}, {nodes, in_ports}) do
    {
      update_in(nodes[name].links, &Keyword.update(&1, port, [dst], fn dsts -> [dst | dsts] end)),
      in_ports
    }
  end

  defp merge({src, dst}, {nodes, in_ports}) do
    {
      nodes,
      Keyword.update!(in_ports, src, fn dsts -> [dst | dsts] end)
    }
  end
end
