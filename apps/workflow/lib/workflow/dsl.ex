defmodule Skitter.Workflow.DSL do
  import Skitter.Workflow.DefinitionError
  import Skitter.Component

  defmacro workflow(name, do: body) do
    try do
      body =
        body
        |> transform_block_to_list()
        |> transform_assigns!()
        |> transform_links()
        |> transform_underscores()
        |> transform_binds!()

      validate_components(body)
      validate_ports(body)

      quote generated: true do
        unquote(name) = unquote(body)
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
        fn links -> [{name, in_port} | links] end
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

  # ---------- #
  # Validation #
  # ---------- #

  # Ensure the provided modules exist and are a skitter component
  defp validate_components(body) do
    Enum.map(body, fn {:{}, _env, [_id, mod, _init, _links]} ->
      mod = Macro.expand(mod, __ENV__)

      unless Code.ensure_loaded?(mod) do
        throw {:error, :unknown_module, mod}
      end

      unless is_component?(mod) do
        throw {:error, :no_component, mod}
      end
    end)
  end

  defp validate_ports(body) do
    validate_out_ports(body)
    validate_in_ports(body)
  end

  defp validate_out_ports(body) do
    Enum.map(body, fn {:{}, _env, [_id, cmp, _init, links]} ->
      cmp = Macro.expand(cmp, __ENV__)

      Enum.map(links, fn {out, _} ->
        unless out in out_ports(cmp) do
          throw {:error, :invalid_port, :out, out, cmp}
        end
      end)
    end)
  end

  defp validate_in_ports(body) do
    binds =
      Enum.reduce(body, Map.new(), fn {:{}, _env, [id, cmp, _init, _links]},
                                      acc ->
        cmp = Macro.expand(cmp, __ENV__)
        Map.put(acc, id, cmp)
      end)

    Enum.map(body, fn {:{}, _env, [_id, _cmp, _init, links]} ->
      Enum.map(links, fn {_, lst} ->
        Enum.map(lst, fn {id, port} ->
          unless port in in_ports(binds[id]) do
            throw {:error, :invalid_port, :in, port, binds[id]}
          end
        end)
      end)
    end)
  end
end
