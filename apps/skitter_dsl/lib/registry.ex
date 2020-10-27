# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.DSL.Registry do
  @moduledoc false
  # Macros to register and read component, strategy and workflow names.
  # Due to technical reasons, names are only bound at runtime. Therefore, any code that needs to
  # resolve a name cannot be executed at compile (macro expansion) time.

  use Agent

  def start_link(_), do: Agent.start_link(fn -> %{} end, name: __MODULE__)

  def names(), do: Agent.get(__MODULE__, &Map.keys/1)

  def bind(name, value) do
    Agent.get_and_update(__MODULE__, fn map ->
      if Map.has_key?(map, name) do
        {:already_defined, map}
      else
        {:ok, Map.put(map, name, value)}
      end
    end)
  end

  def bind!(name, value) do
    case bind(name, value) do
      :ok ->
        value

      :already_defined ->
        raise Skitter.DSL.DefinitionError, "`#{unprefix(name)}` is already defined"
    end
  end

  def lookup(name) do
    case Agent.get(__MODULE__, &Map.get(&1, name, :undefined)) do
      :undefined -> :undefined
      value -> {:ok, value}
    end
  end

  def lookup!(name) do
    case lookup(name) do
      {:ok, value} -> value
      :undefined -> raise Skitter.DSL.DefinitionError, "`#{unprefix(name)}` is not defined"
    end
  end

  @doc """
  Bind `ast` to `name`. If name is `nil`, no binding is created
  """
  defmacro store(ast, nil), do: ast

  defmacro store(ast, name) do
    name = Macro.expand(name, __CALLER__)

    quote do
      unquote(__MODULE__).bind!(unquote(name), unquote(ast))
    end
  end

  defp unprefix(name), do: name |> Atom.to_string() |> String.replace_prefix("Elixir.", "")
end
