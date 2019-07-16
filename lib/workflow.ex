# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Workflow do
  @moduledoc """
  Data processing pipeline.

  A reactive workflow is a collection of connected reactive components and
  which make up a data processing pipeline. This module defines the internal
  representation of a skitter workflow as an elixir struct, along with the
  necessary utilities to operate on this struct. Finally, this module contains
  a macro which can be used to create reactive workflows.
  """
  alias Skitter.{Component, Port, DSL, DefinitionError, Runtime.Registry}

  defstruct name: nil, in_ports: [], out_ports: [], instances: %{}, links: %{}

  @typedoc """
  Internal workflow representation.

  A workflow contains a set of component "instances"; components grouped with
  the arguments that can be used to initialize them. Besides this, a workflow
  has a set of in -and out ports, and an optional name. Finally, the workflow
  stores the links between the various `t:address/0` of ports in the workflow.
  """
  @type t :: %__MODULE__{
          name: String.t() | nil,
          in_ports: [Port.t(), ...],
          out_ports: [Port.t()],
          instances: %{optional(id()) => {Component.t(), [any()]}},
          links: %{required(address()) => [address()]}
        }

  @typedoc """
  Identifier of a component instance in a workflow.
  """
  @type id() :: atom()

  @typedoc """
  Address of a port in a workflow.

  An address can refer to a `t:Skitter.Port.t/0` of an instance in the workflow,
  or to a port of the workflow itself.

  An address is a tuple which identifies an instance in the workflow, and a port
  of this instance. When the address refers to a workflow port, the instance is
  replaced by `nil`.

  Note that it is possible for an in -and out port in a workflow to share an
  address. This happens when a component or workflow defines an in -and out port
  with the same name.
  """
  @type address() :: {id() | nil, Port.t()}

  # ------------------ #
  # Workflow Expansion #
  # ------------------ #

  @doc false
  # Expand the workflow at runtime, needed since names are not registered
  # at compile time.
  def _create_workflow(name, in_ports, out_ports, instances, links) do
    try do
      instances =
        instances
        |> Enum.map(&expand_name/1)
        |> Enum.map(&create_pair/1)
        |> Enum.into(%{})

      links =
        links
        |> verify_links(instances, in_ports, out_ports)
        |> read_links()

      %__MODULE__{
        name: name,
        in_ports: in_ports,
        out_ports: out_ports,
        instances: instances,
        links: links
      }
      |> Registry.put_if_named()
    catch
      err -> handle_error(err)
    end
  end

  defp expand_name({name, comp, args}) when is_atom(comp) do
    case Registry.get(comp) do
      nil -> throw {:error, :invalid_name, comp}
      res -> {name, res, args}
    end
  end

  defp expand_name(any), do: any

  defp create_pair({name, comp, args}) do
    {name, Component.Handler.on_embed(comp, args)}
  end

  defp verify_links(links, instances, in_ports, out_ports) do
    Enum.each(links, fn {source, destination} ->
      verify_port(source, instances, in_ports, :out_ports)
      verify_port(destination, instances, out_ports, :in_ports)
    end)

    links
  end

  defp verify_port({nil, port}, _, ports, _) do
    unless port in ports do
      throw {:error, :invalid_workflow_port, port}
    end
  end

  defp verify_port({identifier, port}, instances, _, key) do
    component =
      case instances[identifier] do
        nil -> throw {:error, :invalid_instance, identifier}
        {component, _args} -> component
      end

    unless port in Map.get(component, key) do
      throw {:error, :invalid_component_port, port, component}
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
  DSL to define skitter workflows.

  Like a component definition, a workflow definition consists of a signature
  and a body. The first two arguments accepted by this macro (`name`, `port`)
  make up the signature, while the final argument contains the body of the
  component.

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

  The body of a workflow contains two possible types of statements: instance
  declarations or links.

  ### Instance declarations

  An instance declaration specifies that a specific component will be used
  by a workflow. It has the following form:

  ```
  <name> = instance <component>, <arg1>, <arg2>
  ```

  - The name of an instance uniquely identifies it in the workflow. This name
  is used by links.
  - The component is either the name of an existing component, or the inline
  definition of a new component.
  - Any other argument passed to the instance declaration is passed as an
  argument when the component is initialized.

  ### Links

  The body of a workflow may contain links. A link is declared through the use
  of the `<source> ~> <destination>` syntax. `source` and `destination` may
  refer to any port in the workflow. The `<name>.<port>` syntax is used to
  identify a port of an instance. `<name>` is used to refer to a port of the
  workflow.

  ## Examples

      iex> defcomponent Identity, in: in_val, out: out_val do
      ...>   react val, do: val ~> out_val
      ...> end
      iex> wf = defworkflow in: data do
      ...>
      ...>   id = instance Identity
      ...>
      ...>   printer = instance (defcomponent in: val do
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
      {instances, links} =
        body
        |> DSL.block_to_list()
        |> verify_statements(__CALLER__)
        |> split_workflow()

      links = read_links(links, __CALLER__)
      instances = read_instances(instances, __CALLER__)

      quote do
        unquote(__MODULE__)._create_workflow(
          unquote(name),
          unquote(in_ports),
          unquote(out_ports),
          unquote(instances),
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

  # Split the workflow into links and instances
  defp split_workflow(statements) do
    Enum.split_with(statements, fn node -> elem(node, 0) == := end)
  end

  # Extract the instances of the workflow
  defp read_instances(statements, env) do
    ast = Enum.map(statements, &read_instance(&1, env))

    quote do
      import Skitter.Component
      unquote(ast)
    end
  end

  # Grab the data from an instance declaration
  defp read_instance({:=, _, [name, func]}, env) do
    name = DSL.name_to_atom(name, env)

    args =
      case Macro.decompose_call(func) do
        {:instance, args} -> args
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

  defp handle_error({:error, :invalid_instance, name}) do
    raise DefinitionError, "`#{name}` does not exist"
  end

  defp handle_error({:error, :invalid_component_port, port, component}) do
    raise DefinitionError,
          "`#{port}` is not a port of `#{inspect(component)}`"
  end
end
