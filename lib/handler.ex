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
  alias Skitter.{Component, Workflow, Instance}
  alias Skitter.Workflow.Node

  alias Skitter.Runtime.MetaHandler, as: Meta
  alias Skitter.Runtime.Registry

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
  def valid?(Meta), do: true
  def valid?(h = %Component{}), do: Component.meta?(h)
  def valid?(_), do: false

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

  @doc section: :hooks
  def on_define(c = %Component{handler: Meta}), do: Meta.on_define(c)

  def on_define(c = %Component{handler: handler}) do
    Component.call(handler, :on_define, %{}, [c]).publish[:component]
  end

  @doc section: :hooks
  def on_embed(n = %Node{elem: %{handler: Meta}}), do: Meta.on_embed(n)

  def on_embed(n = %Node{elem: %Component{handler: handler}}) do
    Component.call(handler, :on_embed, %{}, [n]).publish[:node]
  end

  @doc section: :hooks
  # TODO: Make this use node!
  def deploy(c = %Component{handler: Meta}, args) do
    Meta.deploy(c, args)
  end

  def deploy(c = %Component{handler: handler}, args) do
    deploy(handler, [c, args])
  end

  @doc section: :hooks
  def react(i = %Instance{}, args), do: Meta.react(i, args)

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
        in: [component, node],
        out: [component, node] do
        alias Skitter.Component
        alias Skitter.Component.{Callback, Instance}

        import Skitter.HandlerLib
        import Skitter.Component.Callback

        handler(Meta)
        unquote_splicing(body)
      end
    end
  end
end
