# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Workflow.DSL do
  @moduledoc """
  DSL to define skitter workflows.

  This module defines the `workflow/2` macro, which can be used to create a
  Skitter workflow. This macro is also exported by the `Skitter.Workflow`
  module.

  A Skitter workflow is defined by a name, a set of _in_ports_, a set of
  _instances_ and a set of links. Instances define the component instances that
  will process data flowing through the workflow, while in ports define
  the interface through which data enters the workflow. Links connect in ports
  with instances and instances with other instances.

  As an example, let's look at a workflow which uses the components `Foo` and
  `Bar`. `Foo` has in ports `a` and `b`, and out ports `x` and `y`; `Bar` only
  has a single in port: `val`.

  ```
  import Skitter.Workflow

  workflow Example, in: s do
    s ~> f1.a
    s ~> f1.b

    f1 = instance Foo, {:some_atom, 5}
      f1.x ~> f2.a
      f1.y ~> f2.b

    f2 = instance Foo, {:some_atom, 4}
      f2.y ~> bar.val

    bar = instance Bar
  end
  ```

  This workflow consists of two instances of the same component: `Foo`, an
  instance of the component `Bar` and a single in port `s` which links to `f1`.

  ## Instances

  An instance contains the required information to initialize a component
  instance at run-time. An instance is defined with the following syntax:
  `<name> = instance <Component>` or
  `<name> = instance <Component>, <init argument>`.

  The instance contains the Component and an initialization argument; if the
  latter is not specified, it defaults to `nil`.

  ## Links

  Links define how the various in ports and instances of a workflow are
  connected to each other. A link between an in port and an instance is defined
  with the following syntax: `<in_port_name> ~> <instance_name>.<in_port_name>`.
  This link will ensure that each input received on `<in_port_name>` will
  automatically be sent to the `<in_port_name>` in port of instance
  `<instance_name>`. A link between an out port of an instance and an in-port
  is defined as follows:
  `<instance_name>.<out_port_name> ~> <instance_name>.<in_port_name>`. This link
  will send all of the output published on `<out_port_name>` to in port
  `<in_port_name>` of instance `<instance_name>`.

  Note that an out port or workflow in port may be connected to multiple
  destinations. This is done by providing multiple link statements, as shown in
  the example above.  Besides this, an out port does not have to be connected to
  anything. Output published on an unconnected out port is discarded. In
  contrast to this, every in port of an instance should be connected to at least
  one data source.
  """

  import Skitter.Component

  import Skitter.DSLUtils
  import Skitter.DefinitionError

  @doc """
  Create a skitter workflow.

  This macro serves as the entry point of the `Skitter.Workflow.DSL` DSL.
  Please refer to the module documentation for additional details.
  """
  defmacro workflow(name, ports, do: body) do
    try do
      full_name = module_name_to_snake_case(Macro.expand(name, __CALLER__))
      in_ports = parse_in_ports(ports)

      {body, desc} = extract_description(body)
      moduledoc = generate_moduledoc(desc)

      metadata = %Skitter.Workflow.Metadata{
        name: full_name,
        description: desc,
        in_ports: in_ports
      }

      statements = transform_block_to_list(body)
      verify_statements(statements)
      {instances, links} = split_workflow(statements)

      instances = transform_instances(instances, __CALLER__)
      links = transform_links(links)

      validate_instances(instances, links, metadata)
      validate_links(instances, links, metadata)

      quote do
        defmodule unquote(name) do
          @behaviour unquote(Skitter.Workflow.Behaviour)
          @moduledoc unquote(moduledoc)

          def __skitter_metadata__, do: unquote(Macro.escape(metadata))
          def __skitter_instances__, do: unquote(Macro.escape(instances))
          def __skitter_links__, do: unquote(Macro.escape(links))
        end
      end
    catch
      {:error, :invalid_syntax, other} ->
        inject_error "Invalid workflow syntax: `#{Macro.to_string(other)}`"

      {:error, :duplicate_name, name} ->
        inject_error "Duplicate identifier in workflow: `#{name}`"

      {:error, :unknown_name, name} ->
        inject_error "Unknown identifier: `#{name}`"

      {:error, :unknown_module, mod} ->
        inject_error "`#{mod}` does not exist or is not loaded"

      {:error, :no_component, mod} ->
        inject_error "`#{mod}` is not a skitter component"

      {:error, :invalid_port, type, port, cmp} ->
        type = Atom.to_string(type)
        inject_error "`#{port}` is not a valid #{type} port of `#{cmp}`"

      {:error, :unused_port, diff} ->
        inject_error "Unused in ports present in workflow: `#{inspect(diff)}`"
    end
  end

  # ------------------- #
  # AST Transformations #
  # ------------------- #

  # Get the list of input ports
  defp parse_in_ports(in: in_ports), do: parse_port_names(in_ports)

  # Transform the do block of the workflow into a list of statements.
  # If there is only one statement, wrap it in a list.
  defp transform_block_to_list({:__block__, _, statements}), do: statements
  defp transform_block_to_list(statement), do: [statement]

  # Verify each statement in the workflow is a source or instance statement.
  defp verify_statements(statements) do
    Enum.each(statements, fn
      {:=, _, _} -> :ok
      {:~>, _, _} -> :ok
      any -> throw {:error, :invalid_syntax, any}
    end)
  end

  # Split the workflow into instances and links
  defp split_workflow(statements) do
    Enum.split_with(statements, fn node -> elem(node, 0) == := end)
  end

  # Remove the function name from a call
  defp remove_keyword({kw, _, lst}, kw) when is_list(lst), do: lst
  defp remove_keyword(n, _), do: throw({:error, :invalid_syntax, n})

  # Extract the lhs and rhs of an operator and return as a tuple
  defp transform_operator({op, _, [l, r]}, op), do: {l, r}
  defp transform_operator(n, _), do: throw({:error, :invalid_syntax, n})

  # Turn an elixir name into a symbol
  defp extract_name({name, _, nil}), do: name
  defp extract_name(n), do: throw({:error, :invalid_syntax, n})

  # Transform `a.b` into `{a, b}`
  defp dot_to_tuple({{:., _, [{l, _, _}, r]}, _, _}), do: {l, r}
  defp dot_to_tuple(n), do: throw({:error, :invalid_syntax, n})

  # Transform a list of `name = instance Module, init_args` statements into a
  # map containing `name => {Module, init_args}` elements
  defp transform_instances(instances, env) do
    instances
    |> Stream.map(&transform_operator(&1, :=))
    |> Stream.map(fn {n, i} -> {extract_name(n), i} end)
    |> Stream.map(fn {n, i} -> {n, remove_keyword(i, :instance)} end)
    |> Stream.map(fn
      {n, [m, i]} -> {n, m, i}
      {n, [m]} -> {n, m, nil}
      any -> throw {:error, :invalid_syntax, any}
    end)
    |> Stream.map(fn {n, m, i} -> {n, Macro.expand(m, env), i} end)
    |> Enum.reduce(Map.new(), fn {n, m, i}, map ->
      if Map.has_key?(map, n), do: throw({:error, :duplicate_name, n})
      Map.put(map, n, {m, i})
    end)
  end

  # Transform a list of `l ~> r` statements into a map which contains
  # `lhs => {instance, port}` tuples.
  defp transform_links(sources) do
    sources
    |> Stream.map(&transform_operator(&1, :~>))
    |> Stream.map(fn {l, r} -> {l, dot_to_tuple(r)} end)
    |> Stream.map(fn
      {l = {{:., _, _}, _, _}, r} -> {dot_to_tuple(l), r}
      {l, r} -> {extract_name(l), r}
    end)
    |> Enum.reduce(Map.new(), fn {l, r}, map ->
      Map.update(map, l, [r], &[r | &1])
    end)
  end

  # ---------- #
  # Validation #
  # ---------- #

  # Ensure the provided modules exist and are a skitter component
  defp validate_instances(instances, _, _) do
    Process.sleep(100)
    Enum.map(Map.values(instances), fn {cmp, _init} ->
      unless Code.ensure_compiled?(cmp) do
        throw {:error, :unknown_module, cmp}
      end

      unless is_component?(cmp) do
        throw {:error, :no_component, cmp}
      end
    end)
  end

  # Ensure all the used links are valid
  defp validate_links(instances, links, meta) do
    validate_destinations(instances, links, meta)
    validate_sources(instances, links, meta)
    validate_used(instances, links, meta)
  end

  # Ensure the source of a link exists
  defp validate_sources(instances, links, meta) do
    Enum.map(Map.keys(links), fn
      {i, o} ->
        unless o in out_ports(get_comp(instances, i)) do
          throw({:error, :invalid_port, :out, o, get_comp(instances, i)})
        end

      s ->
        unless s in meta.in_ports do
          throw({:error, :unknown_name, s})
        end
    end)
  end

  # Ensure the destination of a link exists
  defp validate_destinations(instances, links, _) do
    Enum.map(Map.values(links), &Enum.map(&1, fn {i, p} ->
      unless p in in_ports(get_comp(instances, i)) do
        throw {:error, :invalid_port, :in, p, get_comp(instances, i)}
      end
    end))
  end

  defp get_comp(instances, i) do
    case instances[i] do
      nil -> throw {:error, :unknown_name, i}
      {c, _} -> c
    end
  end

  # Ensure all available in ports are used
  defp validate_used(instances, links, _) do
    ports = Enum.flat_map(instances, fn
      {id, {m, _}} -> Enum.map(in_ports(m), fn port -> {id, port} end)
    end)
    dests = links |> Map.values() |> List.flatten()
    diff = MapSet.difference(MapSet.new(ports), MapSet.new(dests))

    unless MapSet.size(diff) == 0 do
      throw {:error, :unused_port, MapSet.to_list(diff)}
    end
  end
end
