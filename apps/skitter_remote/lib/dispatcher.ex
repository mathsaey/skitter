# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Remote.Dispatcher do
  @moduledoc false

  use GenServer

  defstruct map: %{}, default: nil

  # --- #
  # API #
  # --- #

  @doc """
  Start the dispatcher for the current runtime.

  You should not call this yourself, the dispatcher is started as a part of the `:skitter_remote`
  supervision tree.
  """
  @spec start_link(atom()) :: GenServer.on_start()
  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Bind the handling of a certain mode to the calling process.
  """
  @spec bind(atom()) :: :ok
  def bind(mode) do
    GenServer.cast(__MODULE__, {:add, mode, self()})
  end

  @doc """
  Bind the handling of unknown modes to the calling process.
  """
  @spec default_bind() :: :ok
  def default_bind() do
    GenServer.cast(__MODULE__, {:default, self()})
  end

  @doc """
  Return the handler for a given mode.

  Mainly useful for testing purposes.
  """
  def get_handler(mode) do
    GenServer.call(__MODULE__, {:handler, mode})
  end

  @doc """
  Send `message` to the handler for `mode` on `remote`.

  If no handler is found, `{:error, :unknown_mode}` is returned. Otherwise the handler will reply
  to the dispatched message.
  """
  @spec dispatch(node(), atom(), any()) :: {:ok, pid()} | {:error, atom()}
  def dispatch(node, mode, msg) do
    GenServer.call({__MODULE__, node}, {:dispatch, mode, msg})
  end

  # ------ #
  # Server #
  # ------ #

  @impl true
  def init(_) do
    {:ok, %__MODULE__{}}
  end

  @impl true
  def handle_cast({:add, mode, server}, s = %__MODULE__{map: map}) do
    {:noreply, %{s | map: Map.put(map, mode, server)}}
  end

  def handle_cast({:default, server}, s = %__MODULE__{}) do
    {:noreply, %{s | default: server}}
  end

  @impl true
  def handle_call({:handler, mode}, _, s = %__MODULE__{map: map, default: default}) do
    {:reply, Map.get(map, mode, default), s}
  end

  def handle_call({:dispatch, mode, msg}, from, s = %__MODULE__{map: map, default: default}) do
    case Map.get(map, mode, default) do
      nil ->
        {:reply, {:error, :unknown_mode}, s}

      pid ->
        GenServer.cast(pid, {:dispatch, msg, from, mode})
        {:noreply, s}
    end
  end
end
