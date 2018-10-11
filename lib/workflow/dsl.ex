# Copyright 2018, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Workflow.DSL do
  @moduledoc """
  DSL to define skitter workflows.

  This module defines the `workflow/1` macro, which can be used to create a
  Skitter workflow. This macro is also exported by the `Skitter.Workflow`
  module.

  A Skitter workflow is defined by a set of uniquely named _proto-instances_ and
  _sources_. Proto-instances define the components that will process the data
  flowing through a workflow, while sources determine how data that enters the
  workflow is sent to the proto-instances.

  As an example, let's look at a workflow which uses the components `Foo` and
  `Bar`. `Foo` has in ports `a` and `b`, and out ports `x` and `y`; `Bar` only
  has a single in port: `val`.

  ```
  import Skitter.Workflow

  workflow do
    source s ~> {f1.a, f1.b}

    f1 = {Foo, {:some_atom, 5}, x ~> f2.a, y ~> f2.b}
    f2 = {Foo, {:some_atom, 4}, y ~> bar.val}

    bar = {Bar, _}
  end
  ```

  This workflow consists of two proto-instances of the same component: `Foo`,
  a proto-instance of the component `Bar` and a single source `s` which links to
  `Foo`.

  ## Sources

  Sources connect a workflow to the external world and are defined with the
  following syntax:

  ```
  source <name> ~> {<instance identifier>.<port>, <instance identifier>.<port>}

  ```

  Thus, a source definition consists of two parts: a name and a list of
  destinations. A destination is specified as the combination of a
  proto-instance identifier and the name of a valid in port of this
  proto-instance. When a source only links to a single destination, the curly
  braces may be omitted: `source s ~> foo.bar`.

  A workflow may have multiple  sources.

  TODO: Provide additional info when runtime documentation is ready


  ## Proto-instances

  A proto-instance is a tuple which contains all the data that is needed to
  initialize a proper component instance. A proto-instance is defined with the
  following syntax:

  ```
  <name> = {
    <Component>,
    <init argument>,
    <out_port> ~> <instance identifier>.<port>,
    <out_port> ~> <instance identifier>.<port>
  }
  ```

  A proto-instance is defined by a Skitter component, its initialization
  argument and by its links:

  - The component determines the component that will be instantiated inside
  the workflow.
  - The initialization argument will be passed to the `Skitter.Component.init/2`
  function alongside the component to initialize the component instance.
  It can be used to configure the component before it is initialized.
  `_` can be used when no arguments need to be passed.
  - The links determine to which proto-instances this proto-instance is
  connected. A link is specified as a combination of an out port on the
  proto-instance that is being defined, a proto-instance identifier and a valid
  in port on this proto-instance.
  """

  import Skitter.DefinitionError
  import Skitter.Component

  @doc """
  Create a skitter workflow.

  This macro serves as the entry point of the `Skitter.Workflow.DSL` DSL.
  Please refer to the module documentation for additional details.
  """
  defmacro workflow(do: body) do
    try do
      statements = transform_block_to_list(body)
      verify_statements(statements)
      {sources, instances} = split_workflow(statements)

      sources =
        sources
        |> transform_source_syntax()
        |> transform_source_destinations()
        |> transform_source_dots()
        |> sources_to_map()

      instances =
        instances
        |> transform_instance_syntax()
        |> transform_instance_instance()
        |> transform_instance_separate_links()
        |> transform_instance_underscores()
        |> transform_instance_expand_modules(__CALLER__)
        |> transform_instance_transform_links()
        |> instances_to_map(sources)

      workflow = %Skitter.Workflow{instances: instances, sources: sources}

      validate_components(workflow)
      validate_ports(workflow)

      Macro.escape(workflow)
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
        inject_error "Unused in ports present in workflow: `#{inspect diff}`"
    end
  end

  # ----------------------- #
  # General Transformations #
  # ----------------------- #
  #
  # Functionality which transforms the workflow as a whole.

  # Transform the do block of the workflow into a list of statements.
  # If there is only one statement, wrap it in a list.
  defp transform_block_to_list({:__block__, _, statements}), do: statements
  defp transform_block_to_list(statement), do: [statement]

  # Verify each statement in the workflow is a source or instance statement.
  defp verify_statements(statements) do
    Enum.each(statements, fn
      {:=, _, _} -> :ok
      {:source, _, _} -> :ok
      any -> throw {:error, :invalid_syntax, any}
    end)
  end

  # Split the workflow into sources and instances
  defp split_workflow(statements) do
    Enum.split_with(statements, fn node -> elem(node, 0) == :source end)
  end

  # ---------------------- #
  # Syntax Transformations #
  # ---------------------- #
  #
  # Transformations which transform the syntax forms into something more usable.
  # These all throw an `:invalid_syntax` error when they receive some unexpected
  # syntax.

  # Ensure an AST starts with a given keyword.
  defp remove_keyword({kw, _, [args]}, kw), do: args
  defp remove_keyword(n, _), do: throw {:error, :invalid_syntax, n}

  # Extra the lhs and rhs of an operator and return as a tuple
  defp transform_operator({op, _, [l, r]}, op), do: {l, r}
  defp transform_operator(n, _), do: throw({:error, :invalid_syntax, n})

  # Turn an elixir name into a symbol
  defp extract_name({name, _, nil}), do: name
  defp extract_name(n), do: throw({:error, :invalid_syntax, n})

  # Transform a tuple AST into a list of its elements.
  # Treat two-element tuples differently due to Elixir's quoting rules
  # When :wrap is provided as a second argument, wrap arbitrary nodes inside a
  # list.
  defp transform_tuple_to_list({:{}, _, lst}, _) when is_list(lst), do: lst
  defp transform_tuple_to_list({l1, l2}, _), do: [l1, l2]
  defp transform_tuple_to_list(n, :wrap), do: [n]
  defp transform_tuple_to_list(n), do: transform_tuple_to_list(n, :no_wrap)

  # Transform `a.b` into `{a, b}`
  defp transform_dot_to_tuple({{:., _, [{l, _, _}, r]}, _, _}), do: {l, r}
  defp transform_dot_to_tuple(n), do: throw({:error, :invalid_syntax, n})

  # ---------------------- #
  # Source Transformations #
  # ---------------------- #

  # Transform `source name ~> link_statement` into `{name, link_statement}`
  defp transform_source_syntax(sources) do
    Enum.map(sources, fn
      n ->
        {name, links} = n |> remove_keyword(:source) |> transform_operator(:~>)
        {extract_name(name), links}
    end)
  end

  # Obtain the source destination as a list.
  defp transform_source_destinations(sources) do
    Enum.map(sources, fn {name, el} ->
      {name, transform_tuple_to_list(el, :wrap)}
    end)
  end

  # Extract the instance and port name from the dot notation and return it as a
  # tuple i.e., turn a.b into {a, b}
  defp transform_source_dots(sources) do
    Enum.map(sources, fn
      {name, links} -> {name, Enum.map(links, &transform_dot_to_tuple/1)}
    end)
  end

  # Transform the sources list into a map where each source name maps to its
  # links. Throw an error if duplicate source names exist.
  defp sources_to_map(sources) do
    Enum.reduce(sources, Map.new(), fn {name, links}, map ->
      if Map.has_key?(map, name) do
        throw {:error, :duplicate_name, name}
      end

      Map.put(map, name, links)
    end)
  end

  # ------------------------ #
  # Instance Transformations #
  # ------------------------ #

  # Transform `a = ...` into `{a, ...}`
  defp transform_instance_syntax(instances) do
    Enum.map(instances, fn
      n ->
        {name, instance} = transform_operator(n, :=)
        {extract_name(name), instance}
    end)
  end

  # Convert the tuple notation to a list of elements
  defp transform_instance_instance(instances) do
    Enum.map(instances, fn
      {name, instance} -> {name, transform_tuple_to_list(instance)}
    end)
  end

  # Separate the links from the other instance fields, ensure an empty list is
  # provided when no links are present.
  defp transform_instance_separate_links(instances) do
    Enum.map(instances, fn
      {name, instance} ->
        {[mod, init], links} = Enum.split(instance, 2)
        {name, {mod, init, links}}
    end)
  end

  # Transform the use of `_` instances into `nil`
  defp transform_instance_underscores(instances) do
    Enum.map(instances, fn
      {name, {mod, {:_, _, nil}, links}} -> {name, {mod, nil, links}}
      any -> any
    end)
  end

  # Expand component instance module names
  defp transform_instance_expand_modules(instances, env) do
    Enum.map(instances, fn
      {name, {mod, init, links}} ->
        {name, {Macro.expand(mod, env), init, links}}
    end)
  end

  # Transform the link list of an instance into a keyword list where the out
  # port is the key and `{instance, in_port}` is the value
  defp transform_instance_transform_links(instances) do
    Enum.map(instances, fn
      {name, {mod, init, links}} ->
        {name, {mod, init, transform_instance_link_list(links)}}
    end)
  end

  # Does most of the heavy lifting for `transform_instance_transform_links`
  defp transform_instance_link_list(links) do
    links
    |> Enum.map(fn link ->
      {src, dst} = transform_operator(link, :~>)
      {src, {inst, port}} = {extract_name(src), transform_dot_to_tuple(dst)}
      {src, inst, port}
    end)
    |> Enum.reduce(Keyword.new(), fn
      {out, inst, port}, acc ->
        Keyword.update(acc, out, [{inst, port}], &(&1 ++ [{inst, port}]))
    end)
  end

  # Gather the instances in a map, throw an error if duplicate instance names
  # are present, or if the given name is already used for a source
  defp instances_to_map(instances, sources) do
    Enum.reduce(instances, Map.new(), fn {name, instance}, map ->
      if Map.has_key?(map, name) or Map.has_key?(sources, name) do
        throw {:error, :duplicate_name, name}
      end

      Map.put(map, name, instance)
    end)
  end

  # ---------- #
  # Validation #
  # ---------- #

  # Ensure the provided modules exist and are a skitter component
  defp validate_components(%Skitter.Workflow{instances: instances}) do
    Enum.map(Map.values(instances), fn {cmp, _init, _links} ->
      unless Code.ensure_loaded?(cmp) do
        throw {:error, :unknown_module, cmp}
      end

      unless is_component?(cmp) do
        throw {:error, :no_component, cmp}
      end
    end)
  end

  # Ensure all the used ports are valid
  defp validate_ports(%Skitter.Workflow{instances: insts, sources: srcs}) do
    validate_out_ports(insts)
    validate_in_ports(insts, srcs)
  end

  # Ensure the source port is an out port of the component it's linking from
  defp validate_out_ports(instances) do
    Enum.map(Map.values(instances), fn {cmp, _, links} ->
      Enum.map(links, fn {out, _} ->
        unless out in out_ports(cmp) do
          throw {:error, :invalid_port, :out, out, cmp}
        end
      end)
    end)
  end

  defp validate_in_ports(instances, sources) do
    link_destinations = gather_destinations(instances, sources)
    verify_used(gather_in_ports(instances), link_destinations)
    verify_ports(link_destinations, instances)
  end

  # Create a list with the destinations of all connections
  defp gather_destinations(instances, sources) do
    inst_links =
      Enum.flat_map(Map.values(instances), fn {_, _, links} ->
        Enum.flat_map(links, &elem(&1, 1))
      end)

    inst_links ++ Enum.concat(Map.values(sources))
  end

  # Gather a list of usable in ports
  defp gather_in_ports(instances) do
    Enum.flat_map(Map.to_list(instances), fn
      {id, {cmp, _, _}} -> Enum.map(in_ports(cmp), fn port -> {id, port} end)
    end)
  end

  # Ensure each destination component and in ports exists
  defp verify_ports(destinations, instances) do
    Enum.each(destinations, fn
      {id, port} ->
        unless Map.has_key?(instances, id) do
          throw {:error, :unknown_name, id}
        end

        unless port in in_ports(elem(instances[id], 0)) do
          throw {:error, :invalid_port, :in, port, elem(instances[id], 0)}
        end
    end)
  end

  # Ensure all available in ports are used
  defp verify_used(available, used) do
    diff = MapSet.difference(MapSet.new(available), MapSet.new(used))
    unless MapSet.size(diff) == 0 do
      throw {:error, :unused_port, MapSet.to_list(diff)}
    end
  end
end
