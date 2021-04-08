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

  A strategy is defined as an elixir module which implements the `Skitter.Strategy` behaviour.
  Each callback in this behaviour defines a hook that needs to be implemented by the callback. It
  is recommended to define a strategy with `Skitter.DSL.Strategy.defstrategy/3`.

  This module defines the strategy type and behaviour along with functions to call the various
  strategy hooks.
  """
  alias Skitter.{Component, Port, Deployment, Invocation, Worker}

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
          deployment: Deployment.data() | nil,
          invocation: Invocation.t() | nil
        }

  defmodule Context do
    @moduledoc false
    defstruct [:component, :strategy, :deployment, :invocation, :_skr]
  end

  @doc """
  Add code to a component defined with `Skitter.DSL.Component.defcomponent/3`

  This hook is called when a component is defined by the skitter component DSL. It can be used to
  modify the defined component or to verify its properties. Additional information about this hook
  can be found in the documentation of `Skitter.DSL.Component.defcomponent/3`.

  ## Context

  When this hook is called, the `t:context/0` contains the strategy and the module name of the
  component that is being defined. Note that when this hook is called the component module has not
  been compiled yet. It is therefore not possible to use functions defined in `Skitter.Component`
  on this component.
  """
  @callback define(context(), component_info :: Skitter.DSL.Component.info()) ::
              Skitter.DSL.Component.info()

  @doc """
  Deploy a component over the cluster.

  This hook is called by the runtime system when a component has to be distributed over the
  cluster. It receives the arguments passed to `t:Skitter.Workflow.component/0` as its only
  argument. Any data returned by this hook is made available to other hooks through the
  `deployment` field in `t:context/0`.

  ## Context

  When this hook is called, only the current strategy and component are available in the context.
  """
  @callback deploy(context(), args :: any()) :: Deployment.data()

  @doc """
  Send a message to the component.

  This hook is called by the runtime system when data needs to be sent to a given component (e.g.
  when a predecessor of the component publishes data). It receives the data to be sent along with
  the port to which the data should be sent. The result of this hook is ignored.

  ## Context

  All context data (component, strategy, deployment data and the invocation) is available when
  this hook is called.
  """
  @callback send(context(), data :: any(), port :: Port.t() | nil) :: any()

  @doc """
  Handle a message received by the component.

  This hook is called by the runtime when a worker process receives a message. It is called with
  the received message, the data of the worker that received the message and its tag.

  This callback should return a keyword list which may contain the following keys:

  - `state`: the new state of the worker that received the message. If this key is not present the
  state of the worker remains unchanged.

  - `publish`: data to be published. A keyword list of `{port, value}` pairs. `value` will be sent
  to each component connected to `port`. The data will be sent with the invocation contained in
  the context. Mutually exclusive with `publish_with_invocation`.

  - `publish_with_invocation`: data to be published along with an invocation. A keyword list of
  `{port, list}` pairs. `list` is a list of `{value, invocation}` pairs. For every pair, `value`
  will be sent to `port` with `invocation` as its invocation.

  ## Context

  All context data (component, strategy, deployment data and the invocation) is available when
  this hook is called.

  When the received message was not sent by Skitter (i.e. when the worker process received a
  regular message), the invocation is set to `:external`. This can be used by e.g. sources to
  respond to external data.
  """
  @callback receive(context(), message :: any(), state :: Worker.state(), tag :: Worker.tag()) ::
              [
                state: Worker.state(),
                publish: [{Port.t(), any()}],
                publish_with_invocation: [{Port.t(), [{any(), Invocation.t()}]}]
              ]
end
