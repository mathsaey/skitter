# Copyright 2018 - 2022, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.DSL.Component.ControlFlowOperators do
  @moduledoc false
  # State updates in `defcb` are handled by creating hidden variables which keep track of the
  # callback state and emitted data. This approach is a lot faster than using the process
  # dictionary.  One drawback of using this approach is that state updates are sensitive to
  # scoping rules.
  #
  # To solve this, we introduce our own version of common control flow constructs and ensure the
  # modified variables are returned as a part of the result of the control flow construct. These
  # constructs are defined here, to avoid name clashes with the Kernel module in
  # `Skitter.DSL.Component`.

  alias Skitter.DSL.Component
  import Kernel, except: [if: 2]

  # Imports the constructs defined in this module, and ensures those in the kernel are not
  # imported.
  defmacro __using__(_) do
    quote do
      import Kernel, except: [if: 2, unless: 2]
      import unquote(__MODULE__)
    end
  end

  # Rewrite special forms (which cannot be excluded from import)
  def rewrite_special_forms(body) do
    Macro.prewalk(body, fn
      {:try, env, args} -> {:try_, env, args}
      {:case, env, args} -> {:case_, env, args}
      {:cond, env, args} -> {:cond_, env, args}
      {:receive, env, args} -> {:receive_, env, args}
      any -> any
    end)
  end

  defmacro unless(pred, do: thn) do
    quote(do: unless(unquote(pred), do: unquote(thn), else: nil))
  end

  defmacro unless(pred, do: thn, else: els) do
    quote(do: if(unquote(pred), do: unquote(els), else: unquote(thn)))
  end

  defmacro if(pred, do: thn) do
    quote(do: if(unquote(pred), do: unquote(thn), else: nil))
  end

  defmacro if(pred, do: thn, else: els) do
    updates = updates([thn, els])

    quote do
      {result, unquote_splicing(updates)} =
        Kernel.if unquote(pred) do
          result = unquote(thn)
          {result, unquote_splicing(updates)}
        else
          result = unquote(els)
          {result, unquote_splicing(updates)}
        end

      result
    end
  end

  defmacro case_(expr, do: branches) do
    {branches, updates} = rewrite_branches(branches)

    quote do
      {result, unquote_splicing(updates)} =
        case unquote(expr) do
          unquote(branches)
        end

      result
    end
  end

  defmacro cond_(do: branches) do
    {branches, updates} = rewrite_branches(branches)

    quote do
      {result, unquote_splicing(updates)} =
        cond do
          unquote(branches)
        end

      result
    end
  end

  defmacro receive_(do: branches) do
    {branches, updates} = rewrite_branches(branches)

    quote do
      {result, unquote_splicing(updates)} =
        receive do
          unquote(branches)
        end

      result
    end
  end

  defmacro receive_(do: do_branches, after: after_branches) do
    updates = updates(do_branches ++ after_branches)
    do_branches = rewrite_branches(do_branches, updates)
    after_branches = rewrite_branches(after_branches, updates)

    quote do
      {result, unquote_splicing(updates)} =
        receive do
          unquote(do_branches)
        after
          unquote(after_branches)
        end

      result
    end
  end

  defmacro try_(lst) do
    updates = updates(lst)

    quote do
      {result, unquote_splicing(updates)} = try(unquote(Enum.map(lst, &rewrite_try(&1, updates))))
      result
    end
  end

  defp rewrite_try({:rescue, branch}, updates), do: {:rescue, rewrite_branches(branch, updates)}
  defp rewrite_try({:catch, branch}, updates), do: {:catch, rewrite_branches(branch, updates)}

  # Result of after is ignored by elixir, so we do the same here
  # Might be worth providing an error if write or emits occur here in the future
  defp rewrite_try({:after, branch}, _), do: {:after, branch}

  defp rewrite_try({:do, body}, updates) do
    body =
      quote do
        result = unquote(body)
        {result, unquote_splicing(updates)}
      end

    {:do, body}
  end

  # The do block returns possibly updated state and emit data. Need to adjust the matched patterns
  # for this.
  defp rewrite_try({:else, branches}, updates) do
    branches =
      Enum.flat_map(branches, fn
        {:->, _, [head, body]} ->
          quote do
            {unquote_splicing(head), unquote_splicing(updates)} ->
              result = unquote(body)
              {result, unquote_splicing(updates)}
          end
      end)

    {:else, branches}
  end

  defp rewrite_branches(branches) do
    updates = updates(branches)
    branches = rewrite_branches(branches, updates)
    {branches, updates}
  end

  defp rewrite_branches(branches, updates) do
    Enum.flat_map(branches, fn
      {:->, _, [head, body]} ->
        quote do
          unquote_splicing(head) ->
            result = unquote(body)
            {result, unquote_splicing(updates)}
        end
    end)
  end

  defp updates(branches) do
    write? = branches |> Enum.map(&Component.write?/1) |> Enum.any?()
    emit? = branches |> Enum.map(&Component.emit?/1) |> Enum.any?()

    cond do
      write? && emit? -> [Component.state_var(), Component.emit_var()]
      write? -> [Component.state_var()]
      emit? -> [Component.emit_var()]
      true -> []
    end
  end
end
