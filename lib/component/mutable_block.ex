# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Component.MutableBlock do
  @moduledoc false

  @block_keywords [:do, :else, :catch, :rescue, :after]

  # Performan an ast transformation that will ensure the value of `var` is
  # preserved through various scopes in a function body.
  def transform(node = {op, env, args}, var) when is_list(args) do
    args = Enum.map(args, &transform(&1, var))

    if transform_needed?(args) do
      transform_node(node, var)
    else
      {op, env, args}
    end
  end

  def transform(node = {_op, _env, atom}, _) when is_atom(atom), do: node
  def transform(node, _), do: node

  # Check if a function call needs to be transformed (i.e. if it contains any
  # block keywords).
  defp transform_needed?(args) when is_list(args) do
    Enum.any?(
      args,
      fn arg ->
        Keyword.keyword?(arg) and
          Enum.any?(Keyword.keys(arg), &(&1 in @block_keywords))
      end
    )
  end

  # Transform an AST node which contains a code block into a modified node.
  # - The code block of the modified node will return a tuple containing the
  #   original return value and the value of `var`.
  # - An assignment will be added before the ast node which assigns `var` to
  #   `var`, after which it returns the original result from the code block.
  defp transform_node(node, var) do
    {op, env, args} = add_default_branches(node)
    args = transform_args(args, var)
    node = {op, env, args}

    quote do
      {unquote(var), res} = unquote(node)
      res
    end
  end

  defp add_default_branches(node = {op, env, args}) when op in [:if, :unless] do
    [condition, branches] = args

    if :else not in Keyword.keys(branches) do
      args = [condition, branches ++ [else: nil]]
      {op, env, args}
    else
      node
    end
  end

  defp add_default_branches(node), do: node

  # Transform the arguments of an ast node. This function should only be called
  # if `transform_needed?` returned true
  defp transform_args(args, var), do: Enum.map(args, &transform_arg(&1, var))

  defp transform_arg(arg, var) do
    if Keyword.keyword?(arg) do
      Enum.map(arg, &transform_kw_el(&1, var))
    else
      arg
    end
  end

  # Accept an element of a keyword list (a `{key, value}` tuple) and transform
  # the block if the key is a block keyword
  defp transform_kw_el({key, val}, arg) when key in @block_keywords do
    {key, transform_block_argument(val, arg)}
  end

  # Accept the body of a block and transform the body of each of its subclauses
  # with transform_block_or_statement. Needed to handle the different AST types
  # if, case, cond, ... generate
  defp transform_block_argument(lst, var) when is_list(lst) do
    Enum.map(lst, fn {:->, env, [lhs, rhs]} ->
      {:->, env, [lhs, transform_block_or_statement(rhs, var)]}
    end)
  end

  defp transform_block_argument(any, var) do
    transform_block_or_statement(any, var)
  end

  # Take a block or a single statement, return a block which returns a tuple
  # with the original result of the block / statement and `var`.
  defp transform_block_or_statement({:__block__, env, statements}, var) do
    {last, statements} = List.pop_at(statements, -1)
    assign = quote(do: res = unquote(last))
    return = quote(do: {unquote(var), res})
    {:__block__, env, statements ++ [assign, return]}
  end

  defp transform_block_or_statement(statement, var) do
    quote do
      res = unquote(statement)
      {unquote(var), res}
    end
  end
end
