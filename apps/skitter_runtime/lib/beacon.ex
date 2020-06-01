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
  started by the `:skitter_runtime` application. It also defines `discover/1`,
  which can be used to check if a given node is a skitter runtime (i.e. if it
  publishes a beacon).

  A runtime can specify a _mode_ through the `set_local_mode/1` procedure. This
  mode is an atom which identifies the exact purpose this runtime serves in a
  skitter cluster. When no mode is set, the runtime identifies itself as
  `:not_specified`.
  """
  use GenServer

  @doc """
  Start the beacon for the current runtime.
  """
  @spec start_link(atom()) :: GenServer.on_start()
  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Verify if `node` is a skitter runtime. Returns `{:ok, mode}` if it is.

  Note that this procedure will always connect with `node`. If the remote node
  is not a skitter runtime, `Node.disconnect/1` is called automatically.

  The following values may be returned:

  - `{:ok, mode}`: the remote node is a skitter node with mode `mode`.
  - `{:error, :not_distributed}`: the local node is not distributed, so it was
    not possible to connect to the remote node.
  - `{:error, :not_connected}`: it was not possible to connect to the remote
    node.
  - `{:error, :not_skitter}`: the remote node is not a skitter node
  """
  @spec discover(node()) :: {:ok, atom()} | {:error, any()}
  def discover(node) when is_atom(node) do
    with true <- Node.connect(node),
         p when is_pid(p) <- :rpc.call(node, GenServer, :whereis, [__MODULE__]),
         mode <- GenServer.call(p, :mode) do
      {:ok, mode}
    else
      :ignored ->
        {:error, :not_distributed}

      false ->
        {:error, :not_connected}

      nil ->
        Node.disconnect(node)
        {:error, :not_skitter}
    end
  end

  @doc """
  Set the mode of the local skitter runtime.

  Mode can be any atom, besides `:not_specified`, which is the mode of a runtime
  that did not explicitly set a mode.
  """
  @spec set_local_mode(atom()) :: :ok
  def set_local_mode(mode) when is_atom(mode) do
    GenServer.cast(__MODULE__, {:set_mode, mode})
  end

  # ------ #
  # Server #
  # ------ #

  @impl true
  def init([]) do
    {:ok, :not_specified}
  end

  @impl true
  def handle_call(:mode, _, mode) do
    {:reply, mode, mode}
  end

  @impl true
  def handle_cast({:set_mode, mode}, _) do
    {:noreply, mode}
  end
end
