# Copyright 2018 - 2022, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Worker do
  @moduledoc """
  Worker which manages state and performs computations for an operation and its strategy.

  Workers are spawned by strategies to manage state and perform computations for a given
  operation. Any operation or strategy state not stored in the deployment lives in a worker.

  Skitter workers are created by strategies with an initial state. Any messages received by the
  worker are handled by the `c:Skitter.Strategy.Operation.process/4` hook of its strategy. This
  callback receives the current worker state and may return a new, updated state to be stored by
  the worker.

  Since strategies can create many separate workers, each worker is created with a _tag_ which can
  be used by the strategy to provide different implementations of
  `c:Skitter.Strategy.Operation.process/4` based on the worker that received the message.

  This module defines the worker types and various functions to deal with workers.
  """
  alias Skitter.Strategy
  use Skitter.Telemetry

  @typedoc """
  Reference to a created worker.
  """
  @type ref :: pid()

  @typedoc """
  Worker state.
  """
  @type state :: any()

  @typedoc """
  Worker state or a function which returns a worker state.

  Functions which create workers may be created with an initial state, or with a function which
  returns an initial state.
  """
  @type state_or_state_fn :: state() | (() -> state())

  @typedoc """
  Worker tag.

  Each worker is tagged with an atom which allows the strategy to differentiate between the various
  workers it creates.
  """
  @type tag :: atom()

  @typedoc """
  Placement constraints.

  When spawning a remote worker, it is often desirable to tweak on which node the worker will be
  placed.  This type defines a set of placement constraints which can be passed as an argument to
  `create_remote/4`.

  The following constraints are defined:

  - `nil`: No constraints.
  - `on: node`: Spawn the worker at the specified node.
  - `with: ref`: Spawn the worker on the same node as the worker identified by `ref`.
  - `avoid: ref`: Try to place the worker on a different node than the worker identified by `ref`.
  - `avoid: node`: Try to avoid placing the worker on `node`.
  - `tagged: tag`: Try to place the worker on a node with a specific `t:Skitter.Nodes.tag/0`.

  Note that it is not always possible to match the desired constraints. When this is the case, a
  warning will be logged.
  """
  @type placement ::
          nil
          | :local
          | [on: node()]
          | [with: ref()]
          | [avoid: ref() | node()]
          | [tagged: Skitter.Remote.tag()]

  @doc """
  Create a new worker on a remote node.

  The worker will be placed on a random node, subject to the passed placement constraints.
  """
  @spec create_remote(Strategy.context(), state_or_state_fn(), tag(), placement()) :: ref()
  def create_remote(context, state, tag, placement \\ nil) do
    Skitter.Runtime.Spawner.spawn_remote(context, state, tag, placement)
  end

  @doc """
  Create a new worker on the local node.

  This will raise when executed on a master node.
  """
  @spec create_local(Strategy.context(), state_or_state_fn(), tag()) :: ref() | :error
  def create_local(context, state, tag) do
    Skitter.Runtime.Spawner.spawn_local(context, state, tag)
  end

  @doc """
  Send a message to the worker at `ref`.
  """
  @spec send(ref(), any()) :: :ok
  def send(worker, message) do
    Telemetry.emit(
      [:worker, :send],
      %{},
      %{from: self(), to: worker, message: message}
    )

    GenServer.cast(worker, {:sk_msg, message})
  end

  @doc """
  Stop worker `ref`.
  """
  @spec stop(ref()) :: :ok
  def stop(worker) do
    GenServer.cast(worker, :sk_stop)
  end
end
