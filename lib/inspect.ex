# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Inspect do
  @moduledoc false

  defmacro __using__(opts) do
    prefix = Keyword.get(opts, :prefix, "Missing prefix")
    named? = Keyword.get(opts, :named, false)

    quote do
      import Inspect.Algebra
      import unquote(__MODULE__)
      @before_compile unquote(__MODULE__)

      unquote(header(prefix, named?))
      unquote(helpers())
    end
  end

  # Header: Add an inspect which calls _doc. Take care of printing the prefix and the name if
  # needed.
  defp header(prefix, true) do
    quote do
      def inspect(%{name: n}, o = %Inspect.Opts{custom_options: [short: true]})
          when not is_nil(n) do
        to_doc(n, o)
      end

      def inspect(x, o) do
        prefix = group(concat(["##{unquote(prefix)}", _name(x, o), "<"]))
        container_doc(prefix, Map.to_list(x), ">", o, &_doc/2)
      end

      defp _name(%{name: nil}, _), do: empty()
      defp _name(%{name: n}, o), do: concat(["[", to_doc(n, o), "]"])
    end
  end

  defp header(prefix, false) do
    quote do
      def inspect(x, o) do
        container_doc("##{unquote(prefix)}<", Map.to_list(x), ">", o, &_doc/2)
      end
    end
  end

  # Footer: add base cases for `_doc`
  defmacro __before_compile__(_) do
    quote do
      defp _doc({atom, _}, _) when atom in [:__struct__, :name], do: empty()

      defp _doc({k, v}, o) when is_atom(k) do
        group(glue("#{Atom.to_string(k)}:", short(v, o)))
      end

      defp _doc({k, v}, o), do: group(glue(to_doc(k, o), ": ", short(v, o)))
    end
  end

  # Helper functions available inside the module
  defp helpers do
    quote do
      defp short(v, o), do: _to_doc(v, o, true)
      defp long(v, o), do: _to_doc(v, o, false)

      defp _to_doc(v, o, short?) do
        opts = Keyword.merge(o.custom_options, short: short?)
        to_doc(v, %{o | custom_options: opts})
      end
    end
  end

  # --- #
  # DSL #
  # --- #

  defp list_or_wrap(atom) when is_atom(atom), do: [atom]
  defp list_or_wrap(list) when is_list(list), do: list

  defmacro ignore(x) do
    for el <- list_or_wrap(x), do: do_ignore(el)
  end

  defmacro ignore_empty(x) do
    for el <- list_or_wrap(x), do: do_ignore_empty(el)
  end

  defmacro ignore_short(x) do
    for el <- list_or_wrap(x), do: do_ignore_short(el)
  end

  defmacro value_only(x) do
    for el <- list_or_wrap(x), do: do_value_only(el)
  end

  defmacro name_only(x) do
    for el <- list_or_wrap(x), do: do_name_only(el)
  end

  defp do_ignore(k) do
    quote do
      defp _doc({unquote(k), _}, _), do: empty()
    end
  end

  defp do_ignore_empty(k) do
    quote do
      defp _doc({unquote(k), e}, o) when e in [nil, [], %{}], do: empty()
    end
  end

  defp do_ignore_short(k) do
    quote do
      defp _doc({unquote(k), _}, %Inspect.Opts{custom_options: [short: true]}) do
        empty()
      end
    end
  end

  defp do_value_only(k) do
    quote do
      defp _doc({unquote(k), v}, o), do: short(v, o)
    end
  end

  defp do_name_only(k) do
    quote do
      defp _doc({unquote(k), _}, o), do: short(unquote(k), o)
    end
  end

  defmacro match(key, value, opts, do: body) do
    quote do
      defp _doc({unquote(key), unquote(value)}, unquote(opts)) do
        unquote(body)
      end
    end
  end
end
