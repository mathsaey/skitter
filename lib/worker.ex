# Copyright 2018 - 2021, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Worker do
  @moduledoc """
  Worker which manages state and performs computations for a component.

  Workers are spawned by strategies to manage state and perform computations for a given
  component. Any component or strategy state not stored in the deployment lives in a worker.

  Skitter workers are created by strategies with an initial state. Any messages received by the
  worker are handled by the `c:Skitter.Strategy.Component.receive/4` hook of its strategy. This
  callback receives the current worker state and may return a new, udpated state to be stored by
  the worker.

  Since strategies can create many separate workers, each worker is created with a _tag_ which can
  be used by the strategy to provide different implementations of
  `c:Skitter.Strategy.Component.receive/4` based on the worker that received the message.

  This module defines the worker types and various functions to deal with workers.
  """
  alias Skitter.{Strategy, Invocation}

  @typedoc """
  Reference to a created worker.
  """
  @type ref :: pid()

  @typedoc """
  Worker state.
  """
  @type state :: any()

  @typedoc """
  Worker tag.

  Each worker is tagged with an atom which allows the strategy to differentiate between the various
  workers it creates.
  """
  @type tag :: atom()

  @typedoc """
  Placement constraints.

  When spawning a worker, it is often desirable to tweak on which node the worker will be placed.
  This type defines a set of placement constraints which can be passed as an argument to
  `create/4`.

  The following constraints are defined:

  - `nil`: No constraints.
  - `local`: Try to spawn the worker on the local node. Note that this constraints will be ignored
  when executed on a master node.
  - `on: node`: Spawn the worker at the specified node.
  - `with: ref`: Spawn the worker on the same node as the worker identified by `ref`.
  - `avoid: ref`: Try to place the worker on a different node than the worker identified by `ref`.
  Note that it is not always possible to avoid placing two workers on the same node. When this is
  the case, a warning will be logged and both workers will be placed on the same node.
  """
  @type placement :: nil | :local | [on: node()] | [with: ref()] | [avoid: ref()]

  @doc """
  Create a new worker.
  """
  @spec create(Strategy.context(), state(), tag(), placement()) :: ref()
  def create(context, state, tag, placement \\ nil) do
    Skitter.Runtime.Spawner.spawn(context, state, tag, placement)
  end

  @doc """
  Send a message to the worker at `ref`.
  """
  @spec send(ref(), any(), Invocation.t()) :: :ok
  def send(worker, message, invocation) do
    GenServer.cast(worker, {:sk_msg, message, invocation})
  end

  @doc """
  Stop worker `ref`.
  """
  @spec stop(ref()) :: :ok
  def stop(worker) do
    GenServer.cast(worker, :sk_stop)
  end
end
