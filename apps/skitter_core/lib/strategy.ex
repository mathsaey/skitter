# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Strategy do
  @moduledoc """
  Strategy definition and utilities.

  A strategy is a collection of callbacks which determine how a component behaves at compile -and
  runtime. This module documents the strategy type (`t:Skitter.Strategy.t/0`), utilities to deal
  with strategies and the callbacks strategies use to determine the behaviour of components.
  """
  alias Skitter.{Component, Callback}

  @typedoc """
  Strategy representation.

  A strategy is a collection of predefined callbacks, stored inside a struct.  Determines the
  compile -and runtime behaviour of a component.

  In order to allow hierarchies of strategies, some callbacks may remain unimplemented. These
  unimplemented callbacks are represented as `nil`. `complete?/1` can be used to verify if a
  strategy is complete.
  """
  @type t :: %__MODULE__{
          name: module() | nil,
          define: Callback.t() | nil,
          deploy: Callback.t() | nil,
          prepare: Callback.t() | nil,
          send_token: Callback.t() | nil,
          receive_token: Callback.t() | nil,
          receive_message: Callback.t() | nil,
          drop_deployment: Callback.t() | nil,
          drop_invocation: Callback.t() | nil
        }

  defstruct [
    :name,
    :define,
    :deploy,
    :prepare,
    :send_token,
    :receive_token,
    :receive_message,
    :drop_deployment,
    :drop_invocation
  ]

  # --------- #
  # Utilities #
  # --------- #

  @doc """
  Merge a strategy or a group of strategies.

  Two strategies, a `child` and a `parent`, can be merged. When a child and parent strategy are
  merged, every child callback that is undefined (i.e. `nil`) is replaced by the callback in the
  parent, if it is present. Callbacks defined in the child strategy are _not_ overwritten.

  Thus, if we merge a parent strategy which defines `:define` and `:deploy` with a child strategy
  that defines `:deploy` and `:receive_message` we obtain a new strategy which has a definition for
  `:define`, `:deploy` and `:receive_message`. The `:deploy` callback in the merged strategy is
  equal to the `:deploy` strategy of `child`.

      iex> parent_cb = %Callback{function: fn _, _ -> %Callback.Result{result: :parent} end}
      iex> parent = %Strategy{define: parent_cb, deploy: parent_cb}
      #Strategy<:define, :deploy>
      iex> child_cb = %Callback{function: fn _, _ -> %Callback.Result{result: :child} end}
      iex> child = %Strategy{deploy: child_cb, receive_message: child_cb}
      #Strategy<:deploy, :receive_message>
      iex> merged = Strategy.merge(child, parent)
      #Strategy<:define, :deploy, :receive_message>
      iex> Callback.call(merged.define, %{}, [])
      %Callback.Result{result: :parent}
      iex> Callback.call(merged.deploy, %{}, [])
      %Callback.Result{result: :child}
      iex> Callback.call(merged.receive_message, %{}, [])
      %Callback.Result{result: :child}

  It is also possible to merge a child with a list of parent strategies. In this case, the child
  is merged with the first parent in the list, after which the merged strategy is merged with the
  next parent. This is done until no more strategies remain.

  This effectively means that a merge invocation can be read left to right: any callback in the
  returned strategy is the callback of the leftmost strategy in the list of strategies to be
  merged (including the child).

      iex> parent_cb = %Callback{function: fn _, _ -> %Callback.Result{result: :parent} end}
      iex> parent = %Strategy{define: parent_cb}
      #Strategy<:define>
      iex> other_cb = %Callback{function: fn _, _ -> %Callback.Result{result: :other_parent} end}
      iex> other = %Strategy{define: other_cb}
      #Strategy<:define>
      iex> child = %Strategy{}
      #Strategy<>
      iex> merged = Strategy.merge(child, [parent, other])
      #Strategy<:define>
      iex> Callback.call(merged.define, %{}, [])
      %Callback.Result{result: :parent}
      iex> merged = Strategy.merge(child, [other, parent])
      #Strategy<:define>
      iex> Callback.call(merged.define, %{}, [])
      %Callback.Result{result: :other_parent}
      iex> child_cb = %Callback{function: fn _, _ -> %Callback.Result{result: :child} end}
      iex> child = %Strategy{define: child_cb}
      #Strategy<:define>
      iex> merged = Strategy.merge(child, [parent, other])
      #Strategy<:define>
      iex> Callback.call(merged.define, %{}, [])
      %Callback.Result{result: :child}
  """
  @spec merge(t(), t() | [t()]) :: t()
  def merge(child, parents) when is_list(parents) do
    Enum.reduce(parents, child, &merge(&2, &1))
  end

  def merge(child, parent) do
    filtered = child |> Map.from_struct() |> Enum.reject(&(&1 |> elem(1) |> is_nil()))
    struct(%{parent | name: nil}, filtered)
  end

  @doc """
  Verify if a strategy has implementations for every callback.

  ## Examples

      iex> dummy = %Callback{function: fn _, _ -> %Callback.Result{} end}
      iex> Strategy.complete?(%Strategy{name: Example, define: dummy})
      false
      iex> Strategy.complete?(%Strategy{name: Example, define: dummy, deploy: dummy, prepare: dummy, send_token: dummy, receive_token: dummy, receive_message: dummy, drop_invocation: dummy, drop_deployment: dummy})
      true
  """
  @spec complete?(t()) :: boolean()
  def complete?(strategy), do: not incomplete?(strategy)

  @doc """
  Verify whether a strategy is missing an implementation of some callbacks.

  ## Examples

      iex> dummy = %Callback{function: fn _, _ -> %Callback.Result{} end}
      iex> Strategy.incomplete?(%Strategy{name: Example, define: dummy})
      true
      iex> Strategy.incomplete?(%Strategy{name: Example, define: dummy, deploy: dummy, prepare: dummy, send_token: dummy, receive_token: dummy, receive_message: dummy, drop_invocation: dummy, drop_deployment: dummy})
      false
  """
  @spec incomplete?(t()) :: boolean()
  def incomplete?(strategy) do
    strategy
    |> Map.delete(:name)
    |> Map.values()
    |> Enum.any?(&is_nil/1)
  end

  # ----- #
  # Hooks #
  # ----- #

  @doc """
  Activated when a component is defined. Returns a (modified) component.

  This hook is activated when a `t:Skitter.Component.t/0` is defined. It can be used to verify if
  a component is correct (e.g. `Component.require_callback!/3`) or to add additional functionality
  to the component (e.g. `Component.default_callback/3`). Additionally, the strategy can use this
  opportunity to _specialise_ itself

  ## Strategy Specialisation

  Inside the `define` callback, a strategy can change any aspect of a component, including the
  strategy of a component. Thus, a strategy may verify if a component meets some requirement,
  before it replaces itself with a more specialised strategy.
  """
  # NOTE: skitter_core has no way to invoke this hook. Any (domain specific) language built on top
  # of skitter should ensure this is called at the appropriate time.
  @doc section: :hook
  @spec define(Component.t()) :: Component.t() | no_return()
  def define(c = %Component{strategy: %__MODULE__{define: cb}}) do
    Callback.call(cb, %{}, [c]).result
  end

  # @doc """
  # Activated when a worker receives data, returns the new state, published data
  # """
  # # TODO: worker "tags"
  # # TODO: deployment, invocation types
  # @doc section: :hook
  # @spec react(Component.t(), any(), Callback.state(), any(), any()) ::
  #         {Callback.state(), Callback.publish() | nil}
  # def react(c = %Component{strategy: %__MODULE__{react: cb}}, msg, state, d, i) do
  #   res =
  #     Callback.call(cb.react, %{component: c, deployment: d, invocation: i}, [msg, state]).publish

  #   {res[:state], res[:publish]}
  # end
end

defimpl Inspect, for: Skitter.Strategy do
  use Skitter.Inspect, prefix: "Strategy", named: true

  ignore_short([
    :define,
    :deploy,
    :prepare,
    :send_token,
    :receive_token,
    :receive_message,
    :drop_deployment,
    :drop_invocation
  ])

  ignore_empty([
    :define,
    :deploy,
    :prepare,
    :send_token,
    :receive_token,
    :receive_message,
    :drop_deployment,
    :drop_invocation
  ])

  name_only([
    :define,
    :deploy,
    :prepare,
    :send_token,
    :receive_token,
    :receive_message,
    :drop_deployment,
    :drop_invocation
  ])
end
