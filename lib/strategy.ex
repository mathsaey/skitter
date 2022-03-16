# Copyright 2018 - 2022, Mathijs Saey, Vrije Universiteit Brussel

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
  alias Skitter.{Component, Workflow, Invocation}

  @typedoc """
  A strategy is defined as a module.
  """
  @type t :: module()

  @typedoc """
  Constant data of a data processing pipeline.

  A component which is deployed over the cluster has access to an immutable set of data which is
  termed the _deployment_. A strategy can specify which data to store in its deployment inside the
  `c:Skitter.Strategy.Component.deploy/1` hook. Afterwards, the other strategy hooks have access
  to the data stored within the deployment.

  Note that a component strategy can only access its own deployment data.
  """
  @type deployment :: any()

  @typedoc """
  Context information for strategy hooks.

  A strategy hook often needs information about the context in which it is being called. Relevant
  information about the context is stored inside the context, which is passed as the first
  argument to every hook.

  The following information is stored:

  - `component`: The component for which the hook is called.
  - `strategy`: The strategy of the component.
  - `args`: The arguments passed to the component in the workflow.
  - `deployment`: The current deployment data. `nil` if the deployment is not created yet (e.g. in
  `deploy`)
  - `invocation`: The current invocation data. `nil` for hooks that do not have access to the
  invocation.
  - `_skr`: Data stored by the runtime system. This data should not be accessed or modified.
  """
  @type context :: %__MODULE__.Context{
          component: Component.t(),
          strategy: t(),
          args: Workflow.args(),
          deployment: deployment() | nil,
          invocation: Invocation.t() | nil,
          _skr: any()
        }

  defmodule Context do
    @moduledoc false
    @derive {Inspect, except: [:_skr, :deployment, :invocation, :args]}
    defstruct [:component, :strategy, :args, :deployment, :invocation, :_skr]
  end
end
