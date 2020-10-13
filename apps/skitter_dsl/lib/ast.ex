# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.DSL.AST do
  @moduledoc false
  # Private ast transformations for use in DSLs

  # ------- #
  # General #
  # ------- #

  @doc """
  Convert a name AST into an atom.
  """
  def name_to_atom({name, _, a}, _) when is_atom(name) and is_atom(a), do: name
  def name_to_atom(any, env), do: throw({:error, :invalid_syntax, any, env})

  @doc """
  Convert the AST that should be behind `do` into a list of statements.

  This works regardless of whether or not the `do: ...` or `do ... end` syntax
  is used.
  """
  def block_to_list({:__block__, _, statements}), do: statements
  def block_to_list(nil), do: []
  def block_to_list(statement), do: [statement]

  @doc """
  Generate a variable name only usable by macros
  """
  def internal_var(name) do
    var = Macro.var(name, __MODULE__)
    quote(do: var!(unquote(var), unquote(__MODULE__)))
  end

  @doc """
  Remove certain calls from the body.

  Returns the modified body and the extracted calls.
  """
  def extract_calls(body, statements) do
    {body, statements} =
      Enum.map_reduce(body, [], fn
        node = {call, _, _}, acc ->
          if(call in statements, do: {nil, [node | acc]}, else: {node, acc})

        any, acc ->
          {any, acc}
      end)

    body = Enum.reject(body, &is_nil/1)
    {body, statements}
  end

  @doc """
  Parse a list of port names into a list of atoms.

  Returns a tuple containing a list of in port atoms and a list of out ports.
  """
  def parse_port_list([], env), do: parse_port_list([in: [], out: []], env)
  def parse_port_list([in: i], env), do: parse_port_list([in: i, out: []], env)
  def parse_port_list([out: o], env), do: parse_port_list([in: [], out: o], env)

  def parse_port_list(lst = [in: _, out: _], env) do
    lst
    |> Enum.map(&elem(&1, 1))
    |> Enum.map(fn
      lst when is_list(lst) -> lst
      any -> [any]
    end)
    |> Enum.map(fn ports -> Enum.map(ports, &name_to_atom(&1, env)) end)
    |> List.to_tuple()
  end

  def parse_port_list(any, env) do
    throw({:error, :invalid_port_list, any, env})
  end
end
