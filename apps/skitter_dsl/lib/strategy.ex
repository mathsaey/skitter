# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.DSL.Strategy do
  @moduledoc """
  Strategy definition DSL, see `defstrategy/2`.
  """
  alias Skitter.DSL.Registry
  alias Skitter.Component

  # --------- #
  # Utilities #
  # --------- #

  @doc false
  def expand(handler = %Component{}), do: handler

  def expand(name) when is_atom(name) do
    case Registry.get(name) || Code.ensure_loaded?(name) do
      c = %Component{} -> c
      true -> name
      _ -> throw {:error, :invalid_name, name}
    end
  end

  def expand(any), do: throw({:error, :invalid_strategy, any})

  # ------ #
  # Macros #
  # ------ #

  @doc """
  Define a strategy component.

  This macro defines a strategy component. It is a convenient shortcut for using
  `Skitter.DSL.Component.defcomponent/3` with the correct ports, fields and
  strategy for the definition of a strategy.
  """
  defmacro defstrategy(name \\ nil, do: body) do
    body =
      case body do
        {:__block__, _, lst} -> lst
        any -> [any]
      end

    quote do
      import Skitter.DSL.Component, only: [defcomponent: 3]

      defcomponent unquote(name),
        in: [],
        out: [on_define] do
        alias Skitter.{Component, Callback, Callback.Resul, Instance}
        import Skitter.DSL.Callback, only: [defcallback: 4]

        # Import runtime primitives
        # TODO: link to runtime later
        strategy(Meta)

        unquote_splicing(body)
      end
    end
  end
end
