# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Strategy do
  @moduledoc """
  Strategy definition and utilities.

  A strategy is a `t:Skitter.Component.t/0` or a module which determines how a
  component or workflow behaves at compile -and runtime. This module documents
  the strategy type (`t:Skitter.Strategy.t/0`) along with the hooks strategies
  can use to determine the behaviour of components or workflows. Any function
  defined by this module represents a hook.
  """
  alias Skitter.{Element, Component}

  @typedoc """
  Determines the compile -and runtime behaviour of a workflow or component.

  A strategy is a `t:Skitter.Component.t/0` which determines how a component or
  workflow behaves at compile -and runtime. Strategies themselves are components
  which implement various hooks. These hooks are implemented as component
  callbacks.

  Since strategies are components, they need to have a strategy to determine
  their behaviour. Such a strategy, called a _meta strategy_ is provided by a
  runtime implementation. Such a meta strategy is therefore not a component,
  instead, it is represented by a module name which refers to a runtime meta
  strategy.

  In order to support multiple runtime implementations of Skitter, we do not
  refer to a specific runtime module here. However, in general, a skitter
  runtime should offer a meta strategy that is used by all components.
  """
  # TODO: Write a guide that explains how to write a strategy, link to it here
  @type t :: Component.t() | module()

  # ----- #
  # Hooks #
  # ----- #

  @doc """
  Activated on element definition, returns a (modified) element.

  This hook is activated when a `t:Skitter.Element.t/0` is defined. It can be
  used to add functionality to an element, or to ensure that it matches certain
  constraints. This hook should publish an element on the :on_define port, or
  raise an error.
  """
  # Note that this hook is not activated by :skitter_core. Instead, it should be
  # invoked by any (domain-specific) language built on top of :skitter_core.
  @spec on_define(Element.t()) :: Element.t() | no_return()
  def on_define(e = %{strategy: strategy = %Component{}}) do
    Component.call(strategy, :on_define, %{}, [e]).publish[:on_define]
  end

  def on_define(e = %{strategy: strategy}) when is_atom(strategy) do
    strategy.on_define(e)
  end
end
