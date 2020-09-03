# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Strategy do
  @moduledoc false
  @behaviour Skitter.Strategy
  # The strategy for strategies.
  # Like any other component, a skitter strategy needs a strategy. This module defines the runtime
  # strategy, a built in `Skitter.Strategy` which is intended to be used as the strategy of
  # strategies.

  alias Skitter.{Component, Callback}

  # -------------------------------- #
  # Default Callback Implementations #
  # -------------------------------- #
  # Runtime does not depend on DSL, so we define callbacks manually

  @default_on_define %Callback{
    arity: 1,
    state_capability: :none,
    publish_capability: false,
    function: &__MODULE__.default_on_define/2
  }

  @doc false
  def default_on_define(%{}, [comp]), do: %Callback.Result{result: comp}

  @doc false
  def on_define(component) do
    component
    |> Component.default_callback(:on_define, @default_on_define)
    |> Component.require_callback!(:on_define,
      arity: 1,
      state_capability: :none,
      publish_capability: false
    )
  end
end
