# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Component.MetaHandler do
  @moduledoc false

  alias Skitter.{Component, Instance}

  import Skitter.HandlerLib
  import Skitter.Component.Callback, only: [defcallback: 4]

  def on_define(component = %Component{}) do
    component
    |> default_callback(:on_define, defcallback([], [:component], [c], do: c ~> component))
    |> default_callback(:on_embed, defcallback([], [:component, :arguments], [c, a]) do
        c ~> component
        a ~> arguments
      end)
    |> require_callback(:on_define, arity: 1, publish_capability: true)
    |> require_callback(:on_embed, arity: 2, publish_capability: true)
    # |> require_callback(:deploy, arity: 2, publish_capability: true, state_access: :readwrite)
    # |> require_callback(:react, arity: 2, publish_capability: true)
  end

  def on_embed(component, args) do
    component
    |> require_instantiation_arity(args, 0)
  end

  def deploy(handler, args) do
    res = Component.call(handler, :deploy, create_empty_state(handler), args)
    # TODO: Store state on master, not needed for now
    %Instance{elem: handler, ref: res.publish[:reference]}
  end

  def react(%Instance{elem: handler, ref: ref}, args) do
    # React happens on worker node, do not provide state
    Component.call(handler, :react, %{}, [ref, args]).result
  end
end
