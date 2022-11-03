# Copyright 2018 - 2022, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Strategy.Operation do
  @moduledoc """
  Operation strategy behaviour.

  This module defines and documents the various hooks a `Skitter.Strategy` for an operation should
  implement, along with the functions it can use to access the runtime system.
  """
  alias Skitter.{Operation, Strategy, Strategy.Context, Worker}

  @doc """
  Deploy an operation over the cluster.

  This hook is called by the runtime system when an operation has to be distributed over the
  cluster. Any data returned by this hook is made available to other hooks through the
  `deployment` field in `t:Skitter.Strategy.context/0`.

  ## Context

  When this hook is called, only the current strategy, operation and arguments are available in
  the context.
  """
  @callback deploy(context :: Strategy.context()) :: Strategy.deployment()

  @doc """
  Accept data sent to the operation node and send it to a worker.

  This hook is called by the runtime system when data needs to be sent to a given operation (i.e.
  when a predecessor of the operation node emits data). It receives the data to be sent along with
  the index of the port to which the data should be sent.

  The result of this hook is ignored. Instead, this hook should use `Skitter.Worker.send/2` to
  transfer the received data to a worker.

  ## Context

  All context data (operation, strategy and deployment data) is available when this hook is
  called.
  """
  @callback deliver(
              context :: Strategy.context(),
              data :: any(),
              port :: Operation.port_index()
            ) :: any()

  @doc """
  Handle a message received by a worker.

  This hook is called by the runtime when a worker process receives a message. It is called with
  the received message, the data of the worker that received the message and its tag. This hook
  should return the new state of the worker that received the message.

  ## Context

  All context data (operation, strategy and the deployment data) is available when this hook is
  called.
  """
  @callback process(
              context :: Strategy.context(),
              message :: any(),
              state :: Worker.state(),
              tag :: Worker.tag()
            ) :: Worker.state()

  @doc """
  Emit values.

  This function causes the current operation node to emit data. In other words, the provided data
  will be sent to the operation nodes connected to the out ports of the current operation node.
  This function accepts a keyword list of `{out_port, enum}` pairs. Each element in `enum` will be
  sent to the in ports of the operation nodes connected to `out_port`.

  Note that data is emitted from the current worker. This may cause issues when infinite streams
  of data are emitted.
  """
  @spec emit(Strategy.context(), Operation.emit()) :: :ok
  def emit(context = %Context{}, enum), do: Skitter.Runtime.Emit.emit(context, enum)
end
