# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.DSL.Workflow do
  @moduledoc """
  Workflow definition DSL. See `workflow/2` and `defworkflow/3`.
  """
  alias Skitter.{Instance, Component, Workflow}
  alias Skitter.DSL.{DefinitionError, AST}

  # ------------------ #
  # Workflow Expansion #
  # ------------------ #

  @doc false
  # Expand the workflow at runtime, needed since names are not registered at compile time.
  def _create_workflow(in_, out, nodes, links) do
    try do
      nodes = nodes |> Enum.map(&create_node/1) |> Enum.into(%{})
      links = links |> verify_links(nodes, in_, out) |> read_links()

      %Workflow{
        in: in_,
        out: out,
        nodes: nodes,
        links: links
      }
    catch
      err -> handle_error(err)
    end
  end

  defp create_node({n, e, a}) when is_struct(e, Component) or is_struct(e, Workflow) do
    {n, %Instance{elem: e, args: a}}
  end

  defp create_node({_, any, _}), do: throw({:error, :invalid_node, any})

  defp verify_links(links, nodes, in_, out) do
    Enum.each(links, fn {source, destination} ->
      verify_port(source, nodes, in_, :out)
      verify_port(destination, nodes, out, :in)
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
        nil -> throw {:error, :invalid_name, identifier}
        %Instance{elem: element} -> element
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

  @doc """
  Define a workflow using `workflow/2` and bind it to `name`.

  Also sets the `name` field of the generated workflow to `name`.

  ## Examples

      iex> defcomponent identity, in: in_val, out: out_val do
      ...>   strategy test_strategy()
      ...>
      ...>   react val, do: val ~> out_val
      ...> end
      iex> defworkflow workflow, in: data do
      ...>   id = new identity
      ...>
      ...>   printer = new (component in: val do
      ...>      strategy test_strategy()
      ...>      react val, do: IO.inspect(val)
      ...>   end)
      ...>
      ...>   data ~> id.in_val
      ...>   id.out_val ~> printer.val
      ...> end
      iex> workflow.name
      "workflow"
      iex> workflow.in
      [:data]
      iex> workflow.out
      []
      iex> workflow.links
      %{{nil, :data} => [id: :in_val], {:id, :out_val} => [printer: :val]}
  """
  defmacro defworkflow(name, opts \\ [], do: body) do
    name_str = name |> AST.name_to_atom(__CALLER__) |> Atom.to_string()

    quote do
      unquote(name) = %{workflow(unquote(opts), do: unquote(body)) | name: unquote(name_str)}
    end
  end

  @node_keyword :new

  @doc """
  DSL to define `t:Skitter.Workflow.t/0`.

  Like a component definition, a workflow definition consists of a port list and a body. The port
  list declares the ports of the workflow while the final argument contains the body.

  ## Port list

  The in and out ports of a workflow are provided as a list of lists of names, e.g. `in:
  [in_port1, in_port2], out: [out_port1, out_port2]`. As a syntactic convenience, the `[]` around
  a port list may be dropped if only a single port is declared (e.g.: `out: [foo]` can be written
  as `out: foo`). Finally, it is possible for a workflow to not define out ports. This can be
  specified as `out: []`, or by dropping the out port sub-list altogether.

  ## Body

  The body of a workflow contains two possible types of statements: nodes or links.

  ### Nodes

  Nodes specify that a specific element will be used by a workflow. A node is declared with the
  following syntax:

  ```
  <name> = new <element>, <arg1>, <arg2>
  ```

  - The name of a node uniquely identifies it in a workflow. This name is used to link the node to
  others.
  - `element` is a skitter component or workflow.
  - The remaining arguments are stored along with the element as a `t:Skitter.Instance/t/0`. This
  instance is passed to the component strategy when the element is deployed.

  ### Links

  The body of a workflow may contain links. A link is declared through the use of the `<source> ~>
  <destination>` syntax. `source` and `destination` may refer to any port in the workflow. The
  `<name>.<port>` syntax is used to identify a port of a node. `<name>` is used to refer to a port
  of the workflow.

  ## Examples

      iex> identity = component in: in_val, out: out_val do
      ...>   strategy test_strategy()
      ...>
      ...>   react val, do: val ~> out_val
      ...> end
      iex> wf = workflow in: data do
      ...>   id = new identity
      ...>
      ...>   printer = new (component in: val do
      ...>      strategy test_strategy()
      ...>      react val, do: IO.inspect(val)
      ...>   end)
      ...>
      ...>   data ~> id.in_val
      ...>   id.out_val ~> printer.val
      ...> end
      iex> wf.in
      [:data]
      iex> wf.out
      []
      iex> wf.links
      %{{nil, :data} => [id: :in_val], {:id, :out_val} => [printer: :val]}
  """
  @doc section: :dsl
  defmacro workflow(ports \\ [], do: body) do
    try do
      {in_, out} = AST.parse_port_list(ports, __CALLER__)

      {nodes, links} =
        body
        |> AST.block_to_list()
        |> verify_statements(__CALLER__)
        |> split_workflow()

      links = read_links(links, __CALLER__)
      nodes = read_nodes(nodes, __CALLER__)

      quote do
        unquote(__MODULE__)._create_workflow(
          unquote(in_),
          unquote(out),
          unquote(nodes),
          unquote(links)
        )
      end
    catch
      err -> handle_error(err)
    end
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
    name = AST.name_to_atom(name, env)

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
    {AST.name_to_atom(name, env), port}
  end

  defp read_destination(port, env), do: {nil, AST.name_to_atom(port, env)}

  defp handle_error({:error, :invalid_syntax, statement, env}) do
    DefinitionError.inject("Invalid syntax: `#{Macro.to_string(statement)}`", env)
  end

  defp handle_error({:error, :invalid_port_list, any, env}) do
    DefinitionError.inject("Invalid port list: `#{Macro.to_string(any)}`", env)
  end

  defp handle_error({:error, :invalid_workflow_syntax, statement, env}) do
    DefinitionError.inject("`#{Macro.to_string(statement)}` is not allowed in a workflow", env)
  end

  defp handle_error({:error, :invalid_node, any}) do
    raise DefinitionError, "`#{any}` is not a valid component or workflow"
  end

  defp handle_error({:error, :invalid_name, name}) do
    raise DefinitionError, "`#{name}` does not exist"
  end

  defp handle_error({:error, :invalid_workflow_port, port}) do
    raise DefinitionError, "`#{port}` is not a valid workflow port"
  end

  defp handle_error({:error, :invalid_element_port, port, element}) do
    raise DefinitionError, "`#{port}` is not a port of `#{inspect(element)}`"
  end
end
