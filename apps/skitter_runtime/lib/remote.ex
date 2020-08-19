# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Remote do
  @moduledoc """
  Facilities to interact with remote skitter runtimes.
  """
  require Logger
  alias Skitter.Runtime.Beacon

  @doc """
  Connect to `remote` if is a skitter runtime with `mode`.

  This attempts to connect to `remote` through
  `Skitter.Runtime.Beacon.discover/1`.  If this fails for any reason, an
  `{:error, reason}` tuple is returned.  If it succeeds, it verifies if `remote`
  has the desired mode. `{:error, :mode_mismatch}` is returned if this is not
  the case. If the remote runtime has the desired mode, a request is sent to
  `remote` requesting to establish a connection. If this succeeds,
  `{:ok, remote}` is returned. If it fails, `{:error, rejected}` is returned.

  Note that this function calls `Node.monitor/2` when the connection succeeds.
  Thus, the process calling this function should be prepared to handle
  `:nodedown` events.
  """
  @spec connect(node(), module(), atom()) :: :ok | {:error, any()}
  def connect(remote, mode, server) do
    with {:ok, ^mode} <- Beacon.discover(remote),
         true <- GenServer.call({server, remote}, {:accept, Node.self()}) do
      Logger.info("Connected to #{mode}: `#{remote}`")
      Node.monitor(remote, true)
      :ok
    else
      {:error, error} -> {:error, error}
      {:ok, _mode} -> {:error, :mode_mismatch}
      false -> {:error, :rejected}
    end
  end

  @doc """
  Accept or reject a connection attempt from `remote`.

  This function should be called by a `GenServer` handling an `{:accept, remote}`
  call from another skitter runtime. It will return `true` or `false` to
  indicate if the connection was accepted or rejected. This return value should
  be passed to the caller.

  The connection is accepted if `remote` is accepted by
  `Skitter.Runtime.Beacon.discover/1` and if it has mode `mode`. If this is not
  the case, the connection attempt is rejected.

  Note that this function calls `Node.monitor/2` when the connection succeeds.
  Thus, the process calling this function should be prepared to handle
  `:nodedown` events.
  """
  @spec accept(node(), atom()) :: boolean()
  def accept(remote, mode) do
    case Beacon.discover(remote) do
      {:ok, ^mode} ->
        Logger.info("Accepted connection from #{mode}: `#{remote}`")
        Node.monitor(remote, true)
        true

      _ ->
        false
    end
  end

  @doc """
  Execute `mod.func(args)` on every specified remote runtime, obtain results in a list.
  """
  @spec on_many(node(), module(), atom(), [any()]) :: [any()]
  def on_many(workers, mod, func, args) do
    workers
    |> Enum.map(&Task.Supervisor.async({Skitter.Runtime.TaskSupervisor, &1}, mod, func, args))
    |> Enum.map(&Task.await(&1))
  end

  @doc """
  Execute `fun` on every specified remote runtime, obtain results in a list.
  """
  @spec on_many(node(), (() -> any())) :: [any()]
  def on_many(workers, fun) do
    workers
    |> Enum.map(&Task.Supervisor.async({Skitter.Runtime.TaskSupervisor, &1}, fun))
    |> Enum.map(&Task.await(&1))
  end

  @doc """
  Execute `mod.func(args)` on `remote`, block until a result is available.
  """
  @spec on(node(), module(), atom(), [any()]) :: any()
  def on(worker, mod, func, args), do: hd(on_many([worker], mod, func, args))

  @doc """
  Execute `fun` on `remote`, block until a result is available.
  """
  @spec on(node(), (() -> any())) :: any()
  def on(worker, fun), do: hd(on_many([worker], fun))
end