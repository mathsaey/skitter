# Copyright 2018 - 2021, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.DSL.Component.ControlFlowOperators do
  @moduledoc false
  # State updates in `defcb` are handled by creating hidden variables which keep track of the
  # various parts of the callback state. This is a lot faster than using the process dictionary.
  # One drawback of using this approach is that state updates are sensitive to scoping rules.
  #
  # To solve this, we introduce our own version of common control flow constructs and ensure the
  # modified fields are returned as a part of the result of the control flow construct. These
  # constructs are defined here, to avoid name clashes with the Kernel in `Skitter.DSL.Component`.

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
      {:case, env, branches} -> {:case_, env, branches}
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
    fields = fields([thn, els])

    quote do
      {result, unquote_splicing(fields)} =
        Kernel.if unquote(pred) do
          result = unquote(thn)
          {result, unquote_splicing(fields)}
        else
          result = unquote(els)
          {result, unquote_splicing(fields)}
        end

      result
    end
  end

  defmacro case_(expr, do: branches) do
    fields = fields(branches)

    branches =
      Enum.flat_map(branches, fn
        {:->, _, [head, body]} ->
          quote do
            unquote_splicing(head) ->
              result = unquote(body)
              {result, unquote_splicing(fields)}
          end
      end)

    quote do
      {result, unquote_splicing(fields)} =
        case unquote(expr) do
          unquote(branches)
        end

      result
    end
  end

  defp fields(branches) do
    writes = Enum.map(branches, &Component.get_writes/1)
    fields = writes |> Enum.map(&MapSet.new/1) |> Enum.dedup()
    emit? = Enum.any?(branches, &(Component.get_emitted(&1) != []))

    Kernel.if length(fields) == 1 do
      fields = fields |> hd() |> Enum.to_list() |> Enum.map(&Component.state_var/1)
      Kernel.if(emit?, do: [Component.emit_var() | fields], else: fields)
    else
      incompatible_writes(writes)
    end
  end

  defp incompatible_writes(writes) do
    branches =
      writes
      |> Enum.map(fn lst -> lst |> Enum.map(&Atom.to_string/1) |> Enum.join(", ") end)
      |> Enum.with_index(1)
      |> Enum.map(fn {el, idx} -> "\tBranch #{idx} updates: #{el}" end)
      |> Enum.join("\n")

    raise(
      Skitter.DefinitionError,
      """
      Incompatible writes in control structure.
      \tBranches of control flow structures inside `defcb` should mutate the same state fields.
      \tTo solve this problem, ensure all branches mutate the same fields.
      #{branches}
      """
    )
  end
end
