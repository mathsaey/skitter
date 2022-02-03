# Copyright 2018 - 2022, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Strategy.Component do
  @moduledoc """
  Component strategy behaviour.

  This module defines and documents the various hooks a `Skitter.Strategy` for a component should
  implement, along with the functions it can use to access the runtime system.
  """
  alias Skitter.{Component, Strategy, Strategy.Context, Deployment, Invocation, Worker, Port}

  @doc """
  Deploy a component over the cluster.

  This hook is called by the runtime system when a component has to be distributed over the
  cluster. Any data returned by this hook is made available to other hooks through the
  `deployment` field in `t:Skitter.Strategy.context/0`.

  ## Context

  When this hook is called, only the current strategy, component and arguments are available in
  the context.
  """
  @callback deploy(context :: Strategy.context()) :: Deployment.data()

  @doc """
  Accept data sent to the component and send it to a worker.

  This hook is called by the runtime system when data needs to be sent to a given component (i.e.
  when a predecessor of the component emits data). It receives the data to be sent along with the
  index of the port to which the data should be sent.

  The result of this hook is ignored. Instead, this hook should use `Skitter.Worker.send/3` to
  transfer the received data to a worker.

  ## Context

  All context data (component, strategy, deployment data and the invocation) is available when
  this hook is called.
  """
  @callback deliver(context :: Strategy.context(), data :: any(), port :: Port.index()) :: any()

  @doc """
  Handle a message received by a worker.

  This hook is called by the runtime when a worker process receives a message. It is called with
  the received message, the data of the worker that received the message and its tag. This hook
  should return the new state of the worker that received the message.

  ## Context

  All context data (component, strategy, deployment data and the invocation) is available when
  this hook is called.

  When the received message was not sent by Skitter (i.e. when the worker process received a
  regular message), the invocation is set to `:external`. This can be used by e.g. sources to
  respond to external data.
  """
  @callback process(
              context :: Strategy.context(),
              message :: any(),
              state :: Worker.state(),
              tag :: Worker.tag()
            ) :: Worker.state()

  @doc """
  Emit values.

  This function causes the current component to emit data. In other words, the provided data will
  be sent to the components connected to the out ports of the current component. This function
  accepts a keyword list of `{out_port, enum}` pairs. Each element in `enum` will be sent to the
  in ports of the components connected to `out_port`.

  The values are emitted with the invocation of the passed context, use `emit/3` if you need to
  modify the invocation of the data to emit.

  Note that data is emitted from the current worker. This may cause issues when infinite streams
  of data are emitted.
  """
  @spec emit(Strategy.context(), Component.emit()) :: :ok
  def emit(context = %Context{invocation: inv}, emit), do: emit(context, emit, inv)

  @doc """
  Emit values with a custom invocation.

  This function emits values, like `emit/2`. Unlike `emit/2`, this function allows you to specify
  the invocation of the emitted data. An invocation or a 0-arity function which returns an
  invocation should be passed as an invocation to this function. If an invocation is passed, it
  will be used as the invocation for every data element to publish. If a function is passed, it
  will be called once for every data element to publish. The returned invocation will be used as
  the invocation for the data element.
  """
  @spec emit(Strategy.context(), Component.emit(), Invocation.t() | (() -> Invocation.t())) :: :ok
  def emit(context, enum, invocation), do: Skitter.Runtime.Emit.emit(context, enum, invocation)
end
