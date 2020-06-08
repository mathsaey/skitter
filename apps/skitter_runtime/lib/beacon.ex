# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Beacon do
  @moduledoc """
  Facilities to discover, and connect to, skitter nodes.

  To start a skitter cluster, various runtimes in a network need to connect to
  each other and ensure they can cooperate. Skitter runtimes discover each
  other through the use of a _beacon_. Other runtimes can use this beacon or the
  absence thereof to verify if an erlang node is a valid skitter runtime.

  This module defines the beacon process (a genserver) which is automatically
  started by the `:skitter_runtime` application. Other runtimes can use this
  process to verify if this node is a skitter runtime. Upon starting, a skitter
  runtime should call `publish/1` to specify its mode.  Remote runtimes can call
  `discover/1` to obtain the published data, and to verify whether or not they
  are compatible with the local runtime.
  """
  use GenServer
  require Logger

  @doc """
  Start the beacon for the current runtime.

  Called automatically when the `:skitter_runtime` application is started.
  """
  @spec start_link(atom()) :: GenServer.on_start()
  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Publish the local skitter runtime.

  A skitter runtime needs to specify it's _mode_ in order to be published.
  This mode will be sent to remote runtimes that attempt to `discover/1` the
  local node.
  """
  @spec publish(atom()) :: :ok
  def publish(mode), do: GenServer.cast(__MODULE__, {:publish, mode})

  @doc """
  Verify if `node` is a skitter runtime. Returns `{:ok, mode, pid}` if it is.

  Calling this function is the first step to connecting with a remote skitter
  runtime. This procedure will attempt to connect to a remote node, and verify
  that this node is a compatible skitter runtime. When successful, the function
  returns the _mode_ and _remote pid_ of the remote runtime.

  If the local node is not alive (`Node.alive?/0`), `{:error, :not_distributed}`
  is returned. If connection to the remote node is not possible for some other
  reason, `{:error, :not_connected}` is returned.

  Once the connection is established, this function verifies the remote node
  hosts a skitter runtime (i.e. it publishes a `Skitter.Runtime.Beacon`). If
  it does not, `{:error, :not_skitter}` is returned. If it does, the versions
  of the remote and local node are compared, `{:error, :incompatible}` is
  returned if there is a version mismatch between the runtimes.

  Finally, if both runtimes are compatible, a `{:ok, mode}` tuple is returned.
  The _mode_ result indicates the role the remote runtime plays in a skitter
  cluster (e.g. `:master` or `:worker`). `{:error, :uninitialized}` is returned
  if the remote runtime has
  not called `publish/1` yet.
  """
  @spec discover(node()) :: {:ok, atom(), pid()} | {:error, any()}
  def discover(node) when is_atom(node) do
    with {:ok, node} <- try_connect(node),
         {:ok, pid} <- find_beacon(node) do
      probe_beacon(pid)
    end
  end

  defp try_connect(node) do
    case Node.connect(node) do
      :ignored -> {:error, :not_distributed}
      false -> {:error, :not_connected}
      true -> {:ok, node}
    end
  end

  defp find_beacon(node) do
    case :erpc.call(node, GenServer, :whereis, [__MODULE__]) do
      nil ->
        Node.disconnect(node)
        {:error, :not_skitter}

      pid ->
        {:ok, pid}
    end
  end

  defp probe_beacon(pid) do
    local_vsn = version()

    case GenServer.call(pid, :discover) do
      {remote_vsn, _} when remote_vsn != local_vsn -> {:error, :incompatible}
      {_, nil} -> {:error, :uninitialized}
      {_, mode} -> {:ok, mode}
    end
  end

  # ------ #
  # Server #
  # ------ #

  @impl true
  def init([]), do: {:ok, nil, {:continue, nil}}

  @impl true
  def handle_continue(nil, nil), do: {:noreply, {version(), nil}}

  @impl true
  def handle_cast({:publish, mode}, {version, nil}) do
    {:noreply, {version, mode}}
  end

  def handle_cast({:publish, new_mode}, {version, old_mode}) do
    Logger.warn("Replacing `#{old_mode}` with `#{new_mode}`")
    {:noreply, {version, new_mode}}
  end

  @impl true
  def handle_call(:discover, _, state) do
    {:reply, state, state}
  end

  defp version do
    Application.spec(:skitter_runtime, :vsn)
  end
end
