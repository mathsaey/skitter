defmodule Skitter.Workflow.DSL do
  @moduledoc """
  DSL to define skitter workflows.

  This module offers the `workflow/1` macro, which should be used if you plan
  to write a workflow by hand. If you want to automatically generate a workflow
  (e.g. based on the input to some graphical tool), you can use this format or
  the layout described in `Skitter.Component`. Internally, the macro will
  compile its input to the same representation. Additionally, this macro will
  ensure that the workflow does not contain some common errors.

  A workflow definition is a list of component instances with a unique name.
  The following syntax is used:
  `instance_name = {component_module, initialization_arguments, links}`.
  For instance, if we have a component `Foo`, with in ports `a, b, c` and out
  ports: `d, e` we can define the following workflow:

  ```
  workflow do
    instance = {
      Foo, _,
      d ~> other.a,
      d ~> other.b,
      e ~> other.c
    }
    other = {Foo, _}
  end
  ```

  This workflow consists of multiple instances of the same component (`Foo`).
  Foo does not take any initialisation arguments (which is why `_` is used).
  The first instance of `Foo` (`instance`) is linked to the second instance of
  `Foo` (`other`) through the use of the link syntax:
  `out_port ~> instance.in_port`. As shown in the example, multiple links can
  start from the same out port, however, only one incoming link is allowed per
  input port.
  """

  import Skitter.Workflow.DefinitionError
  import Skitter.Component

  @doc """
  Create a skitter workflow.

  This macro serves as the entry point of the `Skitter.Workflow.DSL` DSL.
  Please refer to the module documentation for additional details.
  """
  defmacro workflow(do: body) do
    try do
      body =
        body
        |> transform_block_to_list()
        |> transform_assigns!()
        |> transform_links()
        |> transform_underscores()
        |> transform_binds!()

      requires = body |> extract_modules() |> build_requires()

      validate_components(body, __CALLER__)
      validate_ports(body, __CALLER__)

      quote generated: true do
        alias Skitter.Workflow.Primitive.Source
        unquote(requires)
        unquote(body)
      end
    catch
      {:error, :invalid_syntax, other} ->
        inject_error "Invalid workflow syntax: `#{Macro.to_string(other)}`"

      {:error, :duplicate_name, name} ->
        inject_error "Duplicate component instance name: `#{name}`"

      {:error, :unknown_name, name} ->
        inject_error "Unknown component instance name: `#{name}`"

      {:error, :unknown_module, mod} ->
        inject_error "`#{mod}` does not exist or is not loaded"

      {:error, :no_component, mod} ->
        inject_error "`#{mod}` is not a valid skitter component"

      {:error, :invalid_port, type, port, cmp} ->
        type = Atom.to_string(type)
        inject_error "`#{port}` is not a valid #{type} port of `#{cmp}`"

      {:error, :unused_port, _} ->
        inject_warning("Unused in ports present in workflow")
    end
  end

  # --------------- #
  # Transformations #
  # --------------- #

  # Transform the do block of the workflow into a list of component instances.
  # If there is only one statement, wrap it in a list.
  defp transform_block_to_list({:__block__, _, statements}), do: statements
  defp transform_block_to_list(statement), do: [statement]

  # Transform `name = {...}` statements into `{name, ...}` statements.
  # Ensure that two element tuples are handled properly (as they are a special
  # case in the elixir quoting rules).
  # Ensure all statements are an assignment, throw an error otherwise.
  defp transform_assigns!(body) do
    Enum.map(body, fn
      {:=, _e, [{name, _n, nil}, {a, b}]} -> {:{}, [], [name, a, b]}
      {:=, _e, [{name, _n, nil}, {:{}, env, lst}]} -> {:{}, env, [name | lst]}
      other -> throw {:error, :invalid_syntax, other}
    end)
  end

  # Transform `{id, mod, init, ...}` into `{id, mod, init, [...]}`.
  # This puts all the links between component instances into a dedicated list.
  # Afterwards, transform the list with links with form
  # `{out_port ~> name.in_port}` into a keyword list with items of the form
  # `out_port: [{name, in_port}, {name, in_port}]`
  defp transform_links(body) do
    Enum.map(body, fn {:{}, env, body} ->
      {[id, mod, init], links} = Enum.split(body, 3)
      links = links |> transform_link_syntax() |> gather_links()
      {:{}, env, [id, mod, init, links]}
    end)
  end

  # Transform `out ~> name.in` into a tuple: `{out, name, in}`
  defp transform_link_syntax(links) do
    Enum.map(links, fn {:~>, _arrow_env,
                        [
                          {out_port, _out_env, nil},
                          {{:., _ide, [{name, _ne, nil}, in_port]}, _ode, _da}
                        ]} ->
      {out_port, name, in_port}
    end)
  end

  # Transform a list of links into a keyword list where the links are grouped
  # per output port.
  defp gather_links(links) do
    Enum.reduce(links, [], fn {out_port, name, in_port}, acc ->
      Keyword.update(
        acc,
        out_port,
        [{name, in_port}],
        fn links -> links ++ [{name, in_port}] end
      )
    end)
  end

  # Turn any use of _ as init argument into nil.
  defp transform_underscores(body) do
    Enum.map(body, fn
      {:{}, env, [name, mod, {:_, _, nil}, links]} ->
        {:{}, env, [name, mod, nil, links]}

      any ->
        any
    end)
  end

  # Replace all component instance names, and any references to them with
  # indices.
  defp transform_binds!(body) do
    {body, binds} = bind!(body)
    resolve!(body, binds)
  end

  # Replace all component instance names with an index, return the new AST,
  # alongside a map which contains the bindings between names and indices.
  defp bind!(body) do
    {body, binds} =
      body
      |> Enum.with_index()
      |> Enum.map(fn {{:{}, env, [name, mod, init, links]}, idx} ->
        {{:{}, env, [idx, mod, init, links]}, {name, idx}}
      end)
      |> Enum.unzip()

    binds =
      Enum.reduce(binds, Map.new(), fn {name, idx}, map ->
        Map.update(map, name, idx, fn _ ->
          throw({:error, :duplicate_name, name})
        end)
      end)

    {body, binds}
  end

  # Replace all references to component instance names with indices.
  defp resolve!(body, binds) do
    Enum.map(body, fn {:{}, env, [name, mod, init, links]} ->
      links = resolve_links!(links, binds)
      {:{}, env, [name, mod, init, links]}
    end)
  end

  # Same as `resolve`, but for a specific list of links
  defp resolve_links!(links, binds) do
    Enum.map(links, fn {out_port, lst} ->
      {
        out_port,
        Enum.map(lst, fn {name, port} -> {resolve_link!(name, binds), port} end)
      }
    end)
  end

  # Same as `resolve`, but for a specific link
  defp resolve_link!(name, binds) do
    Map.get_lazy(binds, name, fn -> throw({:error, :unknown_name, name}) end)
  end

  # Extract all the module names
  defp extract_modules(body) do
    Enum.reduce(body, MapSet.new(), fn {:{}, _env, [_name, mod, _init, _links]},
                                       acc ->
      MapSet.put(acc, mod)
    end)
  end

  # Generate `require` statements for a list of (quoted) modules
  defp build_requires(modules) do
    Enum.map(modules, fn mod ->
      quote do
        require unquote(mod)
      end
    end)
  end

  # ---------- #
  # Validation #
  # ---------- #

  # Ensure the provided modules exist and are a skitter component
  defp validate_components(body, env) do
    Enum.map(body, fn {:{}, _env, [_id, mod, _init, _links]} ->
      mod = Macro.expand(mod, env)

      unless Code.ensure_loaded?(mod) do
        throw {:error, :unknown_module, mod}
      end

      unless is_component?(mod) do
        throw {:error, :no_component, mod}
      end
    end)
  end

  # Ensure all the used ports are valid
  defp validate_ports(body, env) do
    validate_out_ports(body, env)
    validate_in_ports(body, env)
  end

  # Ensure the source port is an out port of the component it's linking from
  defp validate_out_ports(body, env) do
    Enum.map(body, fn {:{}, _env, [_id, cmp, _init, links]} ->
      cmp = Macro.expand(cmp, env)

      Enum.map(links, fn {out, _} ->
        unless out in out_ports(cmp) do
          throw {:error, :invalid_port, :out, out, cmp}
        end
      end)
    end)
  end

  # Ensure the destination port of every link exists, and ensure each in port is
  # connected to an out port.
  defp validate_in_ports(body, env) do
    # Gather a map with all components and their id's
    binds =
      Enum.reduce(body, Map.new(), fn {:{}, _env, [id, cmp, _i, _l]}, acc ->
        cmp = Macro.expand(cmp, env)
        Map.put(acc, id, cmp)
      end)

    # Gather a list with all connections
    links =
      Enum.flat_map(body, fn {:{}, _env, [_id, _cmp, _init, links]} ->
        Enum.flat_map(links, fn {_, lst} -> lst end)
      end)

    # Verify if all in ports exist
    Enum.map(links, fn {id, port} ->
      unless port in in_ports(binds[id]) do
        throw {:error, :invalid_port, :in, port, binds[id]}
      end
    end)

    # Make a list with all usable in ports
    usable =
      Enum.flat_map(Map.to_list(binds), fn {id, cmp} ->
        Enum.map(in_ports(cmp), fn port -> {id, port} end)
      end)

    diff = MapSet.difference(MapSet.new(usable), MapSet.new(links))

    unless MapSet.size(diff) == 0 do
      throw {:error, :unused_port, MapSet.to_list(diff)}
    end
  end
end
