# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.DSL.Named do
  @moduledoc false
  # Macros to register and read component, strategy and workflow names.
  # Due to technical reasons, names are only bound at runtime. Therefore, any code that that
  # needs to resolve a name cannot be executed at compile (macro expansion) time.

  defp wrap(name), do: {__MODULE__, name}
  defp unprefix(name), do: name |> Atom.to_string() |> String.replace_prefix("Elixir.", "")

  @doc """
  Verify if a given name is defined.
  """
  def exists?(name), do: name |> wrap() |> :persistent_term.get(nil) |> is_nil() |> Kernel.not()

  @doc """
  Bind `ast` to `name`. If name is `nil`, no binding is created
  """
  defmacro store(ast, nil), do: ast

  defmacro store(ast, name) do
    name = Macro.expand(name, __CALLER__)
    wrapped = wrap(name)

    quote do
      if unquote(__MODULE__).exists?(unquote(name)) do
        raise Skitter.DSL.DefinitionError, "`#{unquote(unprefix(name))}` is already defined"
      else
        :persistent_term.put(unquote(wrapped), unquote(ast))
        unquote(ast)
      end
    end
  end

  @doc """
  Fetch the value for `name`.
  """
  def load(name) do
    wrapped = wrap(name)

    if exists?(name) do
      :persistent_term.get(wrapped)
    else
      raise Skitter.DSL.DefinitionError, "`#{unprefix(name)}` is not defined"
    end
  end

  @doc """
  Retrieve all bound names
  """
  def list() do
    :persistent_term.get()
    |> Enum.filter(&match?({{__MODULE__, _}, _}, &1))
    |> Enum.map(fn {{__MODULE__, name}, _} -> name end)
  end
end
