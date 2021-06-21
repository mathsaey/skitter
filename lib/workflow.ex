# Copyright 2018 - 2021, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Workflow do
  @moduledoc """
  Workflow type definition and utilities.

  A reactive workflow defines a data processing pipeline. It is defined as a set of components
  connected through various links. A workflow stores these components and links, along with some
  additional information about the workflow.

  In order to enable the reuse of workflows, workflows may define in -and out ports. When this is
  done, these workflows may be embedded inside another workflow. Note that a workflow is always
  flattened using `flatten/1` before it is deployed.

  This module defines the workflow type along with some utilities to work with this type. It is
  not recommended to define a workflow manually. Instead, the use of
  `Skitter.DSL.Workflow.workflow/2` is preferred.
  """
  alias Skitter.{Component, Strategy, Port, DefinitionError}

  # ----- #
  # Types #
  # ----- #

  @typedoc """
  Internal workflow representation.

  A workflow is stored as a map, where each name refers to a single node, which is either a
  `t:component/0` or `t:workflow/0`. Besides this, the in -and out ports of the workflow are
  stored. The outgoing links of the in ports of a workflow are stored along with the in ports.
  """
  @type t :: %__MODULE__{
          in: links(),
          out: [Port.t()],
          nodes: %{name() => component() | workflow()}
        }

  defstruct in: [], out: [], nodes: %{}

  @typedoc """
  Component embedded inside a workflow.

  A component in a workflow is stored along with its strategy, initialization arguments (which
  are passed to `c:Skitter.Strategy.Component.deploy/2`) and the outgoing links of each of its out
  ports.

  Workflows can override the strategy of a component, therefore, the strategy specified here may
  not be the same as the strategy returned by `Skitter.Component.strategy/1`.
  """
  @type component :: %__MODULE__.Node.Component{
          component: Component.t(),
          strategy: Strategy.t(),
          args: any(),
          links: links()
        }

  @typedoc """
  Workflow embedded inside a workflow.

  A workflow nested inside a workflow is stored along with the outgoing links of its out ports.
  """
  @type workflow :: %__MODULE__.Node.Workflow{
          workflow: t(),
          links: links()
        }

  @typedoc """
  Collection of outgoing links.

  Links are stored as a keyword list. Each key in this list represents an out port, while the
  value of this key is a list which references the destinations of this out port.
  """
  @type links :: [{Port.t(), [destination()]}]

  @typedoc """
  Link destination.

  This type stores the destination of a link. A link can point to a component or to an out port of
  the workflow. In the first case, the name of the component and the name of the out port are
  stored, in the second, only the name of the out port is stored.
  """
  @type destination :: {name(), Port.t()} | Port.t()

  @typedoc """
  Instance name

  A name is used to refer to a component embedded inside a workflow.
  """
  @type name :: atom()

  # Struct Definitions
  # ------------------

  defmodule Node do
    @moduledoc false
    defmodule Component do
      @moduledoc false
      defstruct [:component, :strategy, :args, links: []]
    end

    defmodule Workflow do
      @moduledoc false
      defstruct [:workflow, links: []]
    end
  end

  # --------- #
  # Utilities #
  # --------- #

  alias __MODULE__.Node.Component, as: C
  alias __MODULE__.Node.Workflow, as: W

  @doc """
  Verify if the links in a workflow are valid.

  This function verifies if every link in the workflow has a valid source and destination. That
  is, the link should depart from an existing workflow or component port and arrive at one. Note
  that this function does _not_ traverse nested workflows.

  ## Examples

      iex> defcomponent Example, in: p, out: p do
      ...> end
      iex> verify(%Workflow{nodes: %{
      ...>   foo: %Node.Component{component: Example, links: [p: [bar: :p]]},
      ...>   bar: %Node.Component{component: Example},
      ...> }})
      :ok
      iex> verify(%Workflow{nodes: %{
      ...>   foo: %Node.Component{component: Example, links: [p: [baz: :p]]},
      ...>   bar: %Node.Component{component: Example},
      ...> }})
      [{{:foo, :p}, {:baz, :p}}]
  """
  @spec verify(t()) :: :ok | [destination()]
  def verify(workflow) do
    destinations = get_destinations(workflow)
    sources = get_sources(workflow)

    workflow
    |> get_links()
    |> Enum.reject(fn {src, dst} -> src in sources and dst in destinations end)
    |> case do
      [] -> :ok
      lst -> lst
    end
  end

  @doc """
  Verify if the links in a workflow are valid using `verify/1`.

  This function uses `verify/1` to verify if every link in a workflow has a valid source and
  destination. If this is not the case, it raises a `Skitter.DefinitionError`. When the workflow
  is valid, the worfklow itself is returned.

  ## Examples

      iex> defcomponent Example, in: p, out: p do
      ...> end
      iex> verify!(%Workflow{nodes: %{
      ...>   foo: %Node.Component{component: Example, links: [p: [bar: :p]]},
      ...>   bar: %Node.Component{component: Example},
      ...> }})
      %Workflow{nodes: %{
        foo: %Node.Component{component: Skitter.WorkflowTest.Example, links: [p: [bar: :p]]},
        bar: %Node.Component{component: Skitter.WorkflowTest.Example},
      }}
      iex> verify!(%Workflow{nodes: %{
      ...>   foo: %Node.Component{component: Example, links: [p: [baz: :p]]},
      ...>   bar: %Node.Component{component: Example},
      ...> }})
      ** (Skitter.DefinitionError) Invalid link: {:foo, :p} ~> {:baz, :p}
  """
  @spec verify!(t()) :: t() | no_return()
  def verify!(workflow) do
    case verify(workflow) do
      :ok ->
        workflow

      [{src, dst} | _] ->
        raise DefinitionError, "Invalid link: #{inspect(src)} ~> #{inspect(dst)}"
    end
  end

  defp get_links(workflow) do
    Enum.flat_map(workflow.nodes, fn
      {name, %{links: links}} -> Enum.map(links, fn {src, dst} -> {{name, src}, dst} end)
    end)
    |> Enum.concat(workflow.in)
    |> Enum.flat_map(fn {src, dsts} -> Enum.map(dsts, fn dst -> {src, dst} end) end)
  end

  defp get_sources(workflow) do
    Enum.flat_map(workflow.nodes, fn
      {name, %C{component: comp}} -> Enum.map(Component.out_ports(comp), &{name, &1})
      {name, %W{workflow: wf}} -> Enum.map(wf.out, &{name, &1})
    end)
    |> Enum.concat(Enum.map(workflow.in, &elem(&1, 0)))
    |> MapSet.new()
  end

  defp get_destinations(workflow) do
    Enum.flat_map(workflow.nodes, fn
      {name, %C{component: comp}} -> Enum.map(Component.in_ports(comp), &{name, &1})
      {name, %W{workflow: wf}} -> Enum.map(wf.in, fn {port, _} -> {name, port} end)
    end)
    |> Enum.concat(workflow.out)
    |> MapSet.new()
  end

  # Flatten
  # -------

  @doc """
  Recursively inline any nested workflow of a workflow.

  This function ensures any workflow embedded in the provided workflow is inlined into the
  provided workflow.

  ## Examples

  ![](assets/docs_workflow_inline_before.png)
  will be converted to:
  ![](assets/docs_workflow_inline_after.png)

      iex> defcomponent Simple, in: p, out: p do
      ...> end
      iex> defcomponent Join, in: [left, right], out: p do
      ...> end
      iex> inner = %Workflow{
      ...>   in: [foo: [node1: :p, node2: :p]],
      ...>   out: [:bar],
      ...>   nodes: %{
      ...>     node1: %Node.Component{component: Simple, links: [p: [node3: :left]]},
      ...>     node2: %Node.Component{component: Simple, links: [p: [node3: :right]]},
      ...>     node3: %Node.Component{component: Join, links: [p: [:bar]]}
      ...> }}
      iex> parent = %Workflow{
      ...>   nodes: %{
      ...>     node_pre: %Node.Component{component: Simple, links: [p: [nested1: :foo, nested2: :foo]]},
      ...>     nested1: %Node.Workflow{workflow: inner, links: [bar: [node_post: :left]]},
      ...>     nested2: %Node.Workflow{workflow: inner, links: [bar: [node_post: :right]]},
      ...>     node_post: %Node.Component{component: Join}
      ...> }}
      iex> flatten(parent)
      %Workflow{
        nodes: %{
          node_pre: %Node.Component{component: Skitter.WorkflowTest.Simple, links: [p: ["nested1#node1": :p, "nested1#node2": :p, "nested2#node1": :p, "nested2#node2": :p]]},
          "nested1#node1": %Node.Component{component: Skitter.WorkflowTest.Simple, links: [p: ["nested1#node3": :left]]},
          "nested1#node2": %Node.Component{component: Skitter.WorkflowTest.Simple, links: [p: ["nested1#node3": :right]]},
          "nested1#node3": %Node.Component{component: Skitter.WorkflowTest.Join, links: [p: [node_post: :left]]},
          "nested2#node1": %Node.Component{component: Skitter.WorkflowTest.Simple, links: [p: ["nested2#node3": :left]]},
          "nested2#node2": %Node.Component{component: Skitter.WorkflowTest.Simple, links: [p: ["nested2#node3": :right]]},
          "nested2#node3": %Node.Component{component: Skitter.WorkflowTest.Join, links: [p: [node_post: :right]]},
          node_post: %Node.Component{component: Skitter.WorkflowTest.Join}
        }
      }
  """
  @spec flatten(t()) :: t()
  def flatten(workflow) do
    workflow
    |> flatten_nested_workflows()
    |> replace_destinations()
    |> replace_nested()
  end

  # Ensure all sub workflows are flattened
  defp flatten_nested_workflows(workflow) do
    nodes = workflow.nodes |> Enum.map(&maybe_flatten_node/1) |> Map.new()
    %{workflow | nodes: nodes}
  end

  defp maybe_flatten_node({name, w = %W{workflow: wf}}), do: {name, %{w | workflow: flatten(wf)}}
  defp maybe_flatten_node(any), do: any

  defp replace_destinations(workflow) do
    nodes =
      workflow.nodes
      |> Enum.map(fn {name, node} ->
        links = Enum.map(node.links, &replace_destinations(&1, workflow))
        {name, %{node | links: links}}
      end)
      |> Map.new()

    %{workflow | nodes: nodes}
  end

  defp replace_destinations({port, destinations}, workflow) do
    destinations =
      Enum.flat_map(destinations, fn
        {name, port} -> replace_destination(workflow.nodes[name], name, port)
        port -> [port]
      end)

    {port, destinations}
  end

  defp replace_destination(%C{}, name, port), do: [{name, port}]

  defp replace_destination(%W{workflow: %__MODULE__{in: links}}, name, port) do
    Enum.map(links[port], fn {dest, port} -> {expand_name(dest, name), port} end)
  end

  defp replace_nested(workflow) do
    nodes =
      workflow.nodes
      |> Enum.flat_map(fn
        {name, node = %W{}} -> inline(name, node)
        any -> [any]
      end)
      |> Map.new()

    %{workflow | nodes: nodes}
  end

  defp inline(name, %W{workflow: workflow, links: links}) do
    Enum.map(workflow.nodes, &update_node(&1, name, links))
  end

  defp update_node({node_name, node}, wf_name, links) do
    {expand_name(node_name, wf_name), %{node | links: update_links(node.links, links, wf_name)}}
  end

  defp update_links(links, wf_links, wf_name) do
    Enum.map(links, fn {port, destinations} ->
      destinations =
        Enum.flat_map(destinations, fn
          {name, port} -> [{expand_name(name, wf_name), port}]
          port -> wf_links[port]
        end)

      {port, destinations}
    end)
  end

  defp expand_name(name, prefix), do: "#{prefix}##{name}" |> String.to_atom()
end
