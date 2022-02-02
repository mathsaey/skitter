# Copyright 2018 - 2021, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Remote.Beacon do
  use GenServer
  require Logger

  defstruct [:mode, :version]

  @doc """
  Start the beacon for the current runtime.
  """
  @spec start_link(atom()) :: GenServer.on_start()
  def start_link(mode) do
    GenServer.start_link(__MODULE__, mode, name: __MODULE__)
  end

  @doc """
  Get the mode of the current node.
  """
  @spec mode() :: atom()
  def mode, do: GenServer.call(__MODULE__, :mode)

  @doc """
  Verify if `node` is a skitter runtime. Returns `{:ok, mode}` if it is.

  Calling this function is the first step to connecting with a remote skitter runtime. This
  procedure will attempt to connect to a remote node, and verify that this node is a compatible
  skitter runtime. When successful, the function returns the _mode_ of the remote runtime.

  If the local node is not alive (`Node.alive?/0`), `{:error, :not_distributed}` is returned. If
  connection to the remote node is not possible for some other reason, `{:error, :not_connected}`
  is returned.

  Once the connection is established, this function verifies the remote node hosts a skitter
  runtime (i.e. it has a `GenServer` name `Skitter.Runtime.Remote.Beacon`). If it does not,
  `{:error, :not_skitter}` is returned. If it does, the versions of the remote and local node are
  compared, `{:error, :incompatible}` is returned if there is a version mismatch between the
  runtimes. If both runtimes are compatible, `{:ok, mode}` is returned, in this tuple, `mode` is
  the mode of the remote runtime.
  """
  @spec verify_remote(node()) ::
          {:ok, atom()}
          | {:error, :not_distributed | :not_connected | :not_skitter | :incompatible}
  def verify_remote(node) when is_atom(node) do
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

    case GenServer.call(pid, :probe) do
      %__MODULE__{version: remote_vsn} when remote_vsn != local_vsn -> {:error, :incompatible}
      %__MODULE__{mode: mode} -> {:ok, mode}
    end
  end

  # ------ #
  # Server #
  # ------ #

  @impl true
  def init(mode) do
    {:ok, %__MODULE__{version: version(), mode: mode}}
  end

  @impl true
  def handle_call(:probe, _, state) do
    {:reply, state, state}
  end

  def handle_call(:mode, _, state) do
    {:reply, state.mode, state}
  end

  defp version do
    Application.spec(:skitter, :vsn)
  end
end
