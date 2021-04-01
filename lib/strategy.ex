# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Strategy do
  @moduledoc """
  Strategy type definition and utilities.

  A strategy is a reusable strategy which determines how a component is distributed at runtime. It
  is defined as a collection of _hooks_: functions which each define an aspect of the distributed
  behaviour of a component.

  A strategy is defined as an elixir module which implements the `Skitter.Strategy` behaviour.
  Each callback in this behaviour defines a hook that needs to be implemented by the callback. It
  is recommended to define a strategy with `Skitter.DSL.Strategy.defstrategy/3`.

  This module defines the strategy type and behaviour along with functions to call the various
  strategy hooks.
  """
  alias Skitter.Component

  @typedoc """
  A strategy is defined as a module.
  """
  @type t :: module()

  @typedoc """
  Context information for strategy hooks.

  A strategy hook often needs information about the context in which it is being called. Relevant
  information about the context is stored inside the context, which is passed as the first
  argument to every hook.

  The following information is stored:

  - `component`: The component for which the hook is called.
  - `strategy`: The strategy of the component.
  - `deployment`: The current deployment data. `nil` if the deployment is not created yet (e.g. in
  `deploy`)
  - `invocation`: The current invocation data. `nil` for hooks that do not have access to the
  invocation.
  """
  @type context :: %__MODULE__.Context{
          component: Component.t(),
          strategy: t(),
          # TODO
          deployment: any() | nil,
          # TODO
          invocation: any() | nil
        }

  defmodule Context do
    @moduledoc false
    defstruct [:component, :strategy, :deployment, :invocation]
  end

  @doc """
  Deploy a component over the cluster.
  """
  @callback deploy(%{component: Component.t()}, [any()]) :: any()
end
