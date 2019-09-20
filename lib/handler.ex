# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Handler do
  @moduledoc """
  Meta facilities for components and workflows.

  Handlers determine the behaviour of components and workflows at compile -and
  runtime.  This module documents the handler type, and documents the hooks a
  handler can use to determine the behaviour of a component or workflow.
  Finally, it provides the `defhandler/2` macro, which can be used to implement
  a component-based handler.

  # TODO: Allow workflow handlers
  # TODO: Allow handler options
  # TODO: Document meta-components and meta-workflows
  """
  alias Skitter.{Component, Workflow, Instance, Element}
  alias Skitter.Instance.Prototype

  alias Skitter.Runtime.Registry
  alias Skitter.Runtime.MetaHandler, as: M

  @typedoc """
  Internal representation of handler type.

  A handler is one of the following:
  - A meta-component
  - A meta-workflow
  - `Meta`. When this handler is used, it specifies that a meta-component is
  being defined. A component which uses the `Meta` handler can be used as a
  handler for other components.
  """
  @type t :: Meta | Component.t() | Workflow.t()

  # --------- #
  # Utilities #
  # --------- #

  @doc false
  def expand(Meta), do: Meta
  def expand(handler = %Component{handler: Meta}), do: handler

  def expand(name) when is_atom(name) do
    case Registry.get(name) do
      nil -> throw {:error, :invalid_name, name}
      handler -> expand(handler)
    end
  end

  def expand(any), do: throw({:error, :invalid_handler, any})

  # ----- #
  # Hooks #
  # ----- #

  @doc """
  Triggers on element definition, returns a (modified) element.

  This hook is activated when a `t:Skitter.Element.t/0` is defined. It can be
  used to add functionality to an element, or to ensure that it matches certain
  constraints. This hook should return an element, or raise an error.
  """
  @doc section: :hooks
  @spec on_define(Element.t()) :: Element.t() | no_return()
  def on_define(e = %{handler: Meta}), do: M.on_define(e)

  def on_define(e = %{handler: handler = %Component{handler: Meta}}) do
    Component.call(handler, :on_define, %{}, [e]).publish[:on_define]
  end

  @doc section: :hooks
  def deploy(n = %Prototype{elem: %{handler: Meta}}), do: M.deploy(n)

  def deploy(n = %Prototype{elem: %{handler: handler}}) do
    deploy(%Prototype{elem: handler, args: [n]})
  end

  @doc section: :hooks
  def react(i = %Instance{}, args), do: M.react(i, args)

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
        {:__block__, _, lst} -> lst
        any -> [any]
      end

    quote do
      import Skitter.Component, only: [defcomponent: 3]

      defcomponent unquote(name),
        in: [elem, prototype],
        out: [elem, reference] do
        alias Skitter.Component
        alias Skitter.Component.Callback

        alias Skitter.Instance
        alias Skitter.Instance.Prototype

        import Skitter.Handler.Primitives
        alias Skitter.Handler.Primitives.{Ubiquitous}

        handler(Meta)
        unquote_splicing(body)
      end
    end
  end
end
