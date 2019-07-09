# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Component.Handler.Utils do
  @moduledoc """
  Reactive component handler utilities.

  This module, which is automatically imported when using
  `Skitter.Component.Handler.defhandler/2`, defines a set of utility functions
  which can be useful when defining a handler.
  """
  alias Skitter.Component
  alias Skitter.Component.Callback

  alias Skitter.HandlerError

  def error(for, message), do: raise(HandlerError, for: for, message: message)

  # --------- #
  # on_define #
  # --------- #

  @doc """
  Add `callback` to `component` with `name` if it does not exist yet.
  """
  @spec default_callback(
          Component.t(),
          Component.callback_name(),
          Callback.t()
        ) :: Component.t()
  def default_callback(component, name, callback) do
    if Map.has_key?(component.callbacks, name) do
      component
    else
      %{component | callbacks: Map.put(component.callbacks, name, callback)}
    end
  end

  @doc """
  Ensure a component defines a given callback.

  Ensures `component` has a callback named `name` with a certain arity, state
  -and publish capability. If this is not the case, it raises a handler error.
  If it is the case, the component is returned unchanged.

  The following options can be provided:
  - `arity`: the arity the callback should have, defaults to `-1`, which accepts
  any arity.
  - `state_capability`: the state capability that is allowed, defaults to `none`
  - `publish_capability`: the publish capability that is allowed, defaults to
  `false`
  """
  @spec require_callback(Component.t(), Component.callback_name(),
          arity: non_neg_integer(),
          state: Callback.state_capability(),
          publish: Callback.publish_capability()
        ) ::
          Component.t() | no_return()
  def require_callback(component, name, opts \\ []) do
    arity = Keyword.get(opts, :arity, -1)
    state = Keyword.get(opts, :state_capability, :none)
    publish = Keyword.get(opts, :publish_capability, false)

    if cb = Map.get(component.callbacks, name) do
      permissions? = Callback.check_permissions(cb, state, publish)
      arity? = Callback.check_arity(cb, arity)

      if permissions? and arity? do
        component
      else
        raise HandlerError,
          for: component,
          message:
            "Invalid implementation of #{name}.\n" <>
              "Wanted: state_capability: #{state}, publish_capability: " <>
              "#{publish}, arity: #{arity}.\n Got: #{inspect(cb)}"
      end
    else
      raise HandlerError, for: component, message: "Missing `#{name}` callback"
    end
  end

  # -------------- #
  # on_instantiate #
  # -------------- #

  def require_instantiation_arity(instance, arity) do
    length = length(instance.instantiation)

    unless length == arity do
      raise HandlerError,
        for: instance,
        message: "Component expects #{arity} arguments, received #{length}"
    end

    instance
  end

  defdelegate create_empty_state(component), to: Component
  defdelegate call(component, callback_name, state, args), to: Component
end
