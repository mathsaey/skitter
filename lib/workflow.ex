# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Workflow do
  @moduledoc """
  Data processing pipeline.

  A reactive workflow is a collection of connected `Skitter.Element` (i.e.
  components or workflows) which make up a data processing pipeline. This module
  defines the internal representation of a skitter workflow as an elixir struct,
  along with the necessary utilities to operate on this struct. Finally, this
  module defines the `defworkflow/3` macro, which can be used to create
  reactive workflows.
  """
  alias Skitter.{Port, DSL, DefinitionError, Runtime.Registry}
  alias Skitter.Workflow.Node

  alias Skitter.Handler
  alias DefaultWorkflowHandler, as: Default

  @behaviour Access

  defstruct name: nil,
            in_ports: [],
            out_ports: [],
            nodes: %{},
            links: %{},
            handler: Default

  @typedoc """
  Internal workflow representation.

  A workflow contains a set of nodes; elements grouped with the arguments that
  can be used to initialize them. Besides this, a workflow has a set of in -and
  out ports, and an optional name. Finally, the workflow stores the links
  between the various `t:address/0` of ports in the workflow.
  """
  @type t :: %__MODULE__{
          name: String.t() | nil,
          in_ports: [Port.t(), ...],
          out_ports: [Port.t()],
          nodes: %{optional(id()) => Node.t()},
          links: %{required(address()) => [address()]},
          handler: Handler.t()
        }

  @typedoc """
  Identifier of a node in a workflow.
  """
  @type id() :: atom()

  @typedoc """
  Address of a port in a workflow.

  An address can refer to a `t:Skitter.Port.t/0` of a node in the workflow, or
  to a port of the workflow itself.

  An address is a tuple which identifies a node in the workflow, and a port of
  this node. When the address refers to a workflow port, the node name is
  replaced by `nil`.

  Note that it is possible for an in -and out port in a workflow to share an
  address. This happens when an element defines an in -and out port with the
  same name.
  """
  @type address() :: {id() | nil, Port.t()}

  # --------- #
  # Utilities #
  # --------- #

  @impl true
  def fetch(wf, key), do: Access.fetch(wf.nodes, key)

  @impl true
  def pop(wf, key), do: Access.pop(wf.nodes, key)

  @impl true
  def get_and_update(wf, key, f) do
    Access.get_and_update(wf.nodes, key, f)
  end

  # ------------------ #
  # Workflow Expansion #
  # ------------------ #

  @doc false
  # Expand the workflow at runtime, needed since names are not registered
  # at compile time.
  def _create_workflow(name, in_ports, out_ports, handler, nodes, links) do
    try do
      nodes =
        nodes
        |> Enum.map(&expand_name/1)
        |> Enum.map(&create_node/1)
        |> Enum.into(%{})

      links =
        links
        |> verify_links(nodes, in_ports, out_ports)
        |> read_links()

      handler = Handler.expand(handler)

      %__MODULE__{
        name: name,
        in_ports: in_ports,
        out_ports: out_ports,
        handler: handler,
        nodes: nodes,
        links: links
      }
      |> Handler.on_define()
      |> Registry.put_if_named()
    catch
      err -> handle_error(err)
    end
  end

  defp expand_name({name, elem, args}) when is_atom(elem) do
    case Registry.get(elem) do
      nil -> throw {:error, :invalid_name, elem}
      res -> {name, res, args}
    end
  end

  defp expand_name(any), do: any

  defp create_node({name, elem, args}) do
    node = %Node{elem: elem, args: args}
    {name, Handler.on_embed(node)}
  end

  defp verify_links(links, nodes, in_ports, out_ports) do
    Enum.each(links, fn {source, destination} ->
      verify_port(source, nodes, in_ports, :out_ports)
      verify_port(destination, nodes, out_ports, :in_ports)
    end)

    links
  end

  defp verify_port({nil, port}, _, ports, _) do
    unless port in ports do
      throw {:error, :invalid_workflow_port, port}
    end
  end

  defp verify_port({identifier, port}, nodes, _, key) do
    element =
      case nodes[identifier] do
        nil -> throw {:error, :invalid_node, identifier}
        %Node{elem: element} -> element
      end

    unless port in Map.get(element, key) do
      throw {:error, :invalid_element_port, port, element}
    end
  end

  defp read_links(links) do
    Enum.reduce(links, %{}, fn {source, destination}, links ->
      Map.update(links, source, [destination], &[destination | &1])
    end)
  end

  # ------ #
  # Macros #
  # ------ #

  @node_keyword :new

  @doc """
  DSL to define skitter workflows.

  Like a component definition, a workflow definition consists of a signature
  and a body. The first two arguments accepted by this macro (`name`, `port`)
  make up the signature, while the final argument contains the body of the
  workflow.

  ## Signature

  The signature of a workflow declares the externally visible information of the
  workflow: its name and list of in -and out ports.

  The name of the workflow is an atom, which is used to register the workflow.
  Workflows are named with an elixir alias (e.g. `MyWorkflow`). The name of
  the workflow is often omitted, in which case it is not registered.

  The in and out ports of a workflow are provided as a list of lists of names,
  e.g. `in: [in_port1, in_port2], out: [out_port1, out_port2]`. As a syntactic
  convenience, the `[]` around a port list may be dropped if only a single port
  is declared (e.g.: `out: [foo]` can be written as `out: foo`). Finally, it is
  possible for a workflow to not define out ports. This can be specified as
  `out: []`, or by dropping the out port sub-list altogether.

  ## Body

  The body of a workflow contains two possible types of statements: nodes or
  links.

  ### Nodes

  Nodes specify that a specific element will be used by a workflow. A node is
  declared with the following syntax:

  ```
  <name> = new <element>, <arg1>, <arg2>
  ```

  - The name of a node uniquely identifies it in a workflow. This name is used
  to link the node to others.
  - `element` is either the name of an existing `Skitter.Element`, or an inline
  definition of an element.
  - Any other argument is stored as a part of the node. When the element gets
  deployed, these arguments are passed to the `Skitter.Handler.deploy/2` hook
  along with the element.

  ### Links

  The body of a workflow may contain links. A link is declared through the use
  of the `<source> ~> <destination>` syntax. `source` and `destination` may
  refer to any port in the workflow. The `<name>.<port>` syntax is used to
  identify a port of a node. `<name>` is used to refer to a port of the
  workflow.

  ## Examples

      iex> defcomponent Identity, in: in_val, out: out_val do
      ...>   react val, do: val ~> out_val
      ...> end
      iex> wf = defworkflow in: data do
      ...>
      ...>   id = new Identity
      ...>
      ...>   printer = new (defcomponent in: val do
      ...>      react val, do: IO.inspect(val)
      ...>   end)
      ...>
      ...>   data ~> id.in_val
      ...>   id.out_val ~> printer.val
      ...> end
      iex> wf.in_ports
      [:data]
      iex> wf.out_ports
      []
      iex> wf.links
      %{{nil, :data} => [id: :in_val], {:id, :out_val} => [printer: :val]}
  """
  @doc section: :dsl
  defmacro defworkflow(name \\ nil, ports, do: body) do
    try do
      # Header data
      name = Macro.expand(name, __CALLER__)
      {in_ports, out_ports} = Port.parse_list(ports, __CALLER__)

      # Parse body
      body = DSL.block_to_list(body)
      {body, handler} = DSL.extract_calls(body, [:handler])
      handler = read_handler(handler, __CALLER__)

      {nodes, links} =
        body
        |> verify_statements(__CALLER__)
        |> split_workflow()

      links = read_links(links, __CALLER__)
      nodes = read_nodes(nodes, __CALLER__)

      quote do
        unquote(__MODULE__)._create_workflow(
          unquote(name),
          unquote(in_ports),
          unquote(out_ports),
          unquote(handler),
          unquote(nodes),
          unquote(links)
        )
      end
    catch
      err -> handle_error(err)
    end
  end

  # Ensure only a single handler is present, extract it
  defp read_handler([], _), do: Default
  defp read_handler([{:handler, _, [handler]}], _), do: handler

  defp read_handler([_, dup | _], env) do
    throw {:error, :duplicate_handler, dup, env}
  end

  # Ensure only valid workflow statements are present
  defp verify_statements(statements, env) do
    Enum.map(statements, fn
      s = {:=, _, _} -> s
      s = {:~>, _, _} -> s
      any -> throw {:error, :invalid_workflow_syntax, any, env}
    end)
  end

  # Split the workflow into links and nodes
  defp split_workflow(statements) do
    Enum.split_with(statements, fn node -> elem(node, 0) == := end)
  end

  # Extract the nodes of the workflow
  defp read_nodes(statements, env) do
    ast = Enum.map(statements, &read_node(&1, env))

    quote do
      import Skitter.Component
      unquote(ast)
    end
  end

  # Grab the data from a node declaration
  defp read_node({:=, _, [name, func]}, env) do
    name = DSL.name_to_atom(name, env)

    args =
      case Macro.decompose_call(func) do
        {@node_keyword, args} -> args
        _ -> throw {:error, :invalid_syntax, func, env}
      end

    {[comp], args} = Enum.split(args, 1)
    {:{}, [], [name, comp, args]}
  end

  defp read_links(statements, env) do
    Enum.map(statements, fn
      {:~>, _, [left, right]} ->
        {read_destination(left, env), read_destination(right, env)}
    end)
  end

  defp read_destination({{:., _, [name, port]}, _, _}, env) do
    {DSL.name_to_atom(name, env), port}
  end

  defp read_destination(port, env), do: {nil, DSL.name_to_atom(port, env)}

  defp handle_error({:error, :invalid_syntax, statement, env}) do
    DefinitionError.inject(
      "Invalid syntax: `#{Macro.to_string(statement)}`",
      env
    )
  end

  defp handle_error({:error, :invalid_port_list, any, env}) do
    DefinitionError.inject("Invalid port list: `#{Macro.to_string(any)}`", env)
  end

  defp handle_error({:error, :duplicate_handler, handler, env}) do
    DefinitionError.inject(
      "Only one handler declaration is allowed: `#{Macro.to_string(handler)}`",
      env
    )
  end

  defp handle_error({:error, :invalid_workflow_syntax, statement, env}) do
    DefinitionError.inject(
      "`#{Macro.to_string(statement)}` is not allowed in a workflow",
      env
    )
  end

  defp handle_error({:error, :invalid_name, name}) do
    raise DefinitionError, "`#{name}` is not defined"
  end

  defp handle_error({:error, :invalid_workflow_port, port}) do
    raise DefinitionError, "`#{port}` is not a valid workflow port"
  end

  defp handle_error({:error, :invalid_node, name}) do
    raise DefinitionError, "`#{name}` does not exist"
  end

  defp handle_error({:error, :invalid_element_port, port, element}) do
    raise DefinitionError,
          "`#{port}` is not a port of `#{inspect(element)}`"
  end
end

defimpl Inspect, for: Skitter.Workflow do
  use Skitter.Inspect, prefix: "Workflow", named: true

  ignore_empty([:out_ports])
  ignore_short([:handler, :nodes, :links])

  describe(:in_ports, "in")
  describe(:out_ports, "out")
end
