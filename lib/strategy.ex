# Copyright 2018 - 2021, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Strategy do
  @moduledoc """
  Strategy type definition and utilities.

  A strategy is a reusable strategy which determines how a component is distributed at runtime. It
  is defined as a collection of _hooks_: functions which each define an aspect of the distributed
  behaviour of a component.

  A strategy is defined as an elixir module which implements the `Skitter.Strategy.Component`
  behaviour.  It is recommended to define a strategy with `Skitter.DSL.Strategy.defstrategy/3`.

  This module defines the strategy and context types.
  """
  alias Skitter.{Component, Deployment}

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
  - `_skr`: Data stored by the runtime system. This data should not be accessed or modified.
  """
  @type context :: %__MODULE__.Context{
          component: Component.t(),
          strategy: t(),
          deployment: Deployment.data() | nil,
          _skr: any()
        }

  defmodule Context do
    @moduledoc false
    @derive {Inspect, except: [:_skr]}
    defstruct [:component, :strategy, :deployment, :_skr]
  end
end
