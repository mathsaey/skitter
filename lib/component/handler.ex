# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Component.Handler do
  @moduledoc """
  Reactive component handler utilities.

  Handlers determine the behaviour of a component at compile -and runtime.
  This module documents handlers, and provides (private) utility functions which
  are used by skitter infrastructure to call these hooks at the appropriate
  time.

  Finally, it provides a macro which allows one to implement a
  component which acts as a component handler.

  # TODO: Allow workflow handlers
  """
  alias Skitter.{Component, Workflow, Registry}
  alias Skitter.Component.MetaHandler, as: Meta

  @typedoc """
  Reactive component handler type.

  A reactive component handler is one of the following:
  - A meta-component
  - A workflow that consists of meta-components
  - `Meta`. When this handler is used, it specifies that a meta-component is
  being defined. A component which uses the `Meta` handler can be used as a
  handler for other components.
  """
  @type t :: Meta | Component.t() | Workflow.t()

  # --------- #
  # Utilities #
  # --------- #

  @doc """
  Verify if a component is a meta-component
  """
  def meta_component?(%Component{handler: Meta}), do: true
  def meta_component?(a) when is_atom(a), do: meta_component?(Registry.get(a))
  def meta_component?(_), do: false

  @doc """
  Verify if a handler is valid, as described in `t:t/0`
  """
  def valid_handler?(Meta), do: true
  def valid_handler?(h = %Component{}), do: meta_component?(h)
  def valid_handler?(_), do: false

  @doc false
  def _expand(Meta), do: Meta
  def _expand(handler = %Component{handler: Meta}), do: handler

  def _expand(name) when is_atom(name) do
    case Registry.get(name) do
      nil -> throw {:error, :invalid_name, name}
      handler -> _expand(handler)
    end
  end

  def _expand(any), do: throw({:error, :invalid_handler, any})

  # ----- #
  # Hooks #
  # ----- #

  @doc section: :hooks
  def on_compile(c = %Component{handler: Meta}), do: Meta.on_compile(c)

  # ------ #
  # Macros #
  # ------ #

  @doc """
  Define a meta-component.

  This macro is syntactic sugar for defining a component using
  `Skitter.Component.defcomponent/3`. The handler and ports of this component
  do not need to be specified, as they are defined by this macro.
  The body of the component is defined using the DSL offered by
  `Skitter.Component.defcomponent/3`.
  """
  @doc section: :dsl
  defmacro defhandler(name \\ nil, do: body) do
    body =
      case body do
        {:__block__, _, []} -> nil
        any -> any
      end

    quote do
      import Skitter.Component

      defcomponent unquote(name), in: [] do
        handler(Meta)
        unquote(body)
      end
    end
  end
end
