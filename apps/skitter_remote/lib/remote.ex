defmodule Skitter.Remote do
  @moduledoc """
  Module to handle interaction with other Skitter runtimes.

  A Skitter cluster consists of various connected runtimes. This module contains the required
  abstractions which allow the current runtime (i.e. an erlang "node") to discover other skitter
  runtimes and to be discovered by them.

  In order to interact with other runtimes, a skitter runtime needs to set up its local _mode_ and
  some _handlers_. The mode of a skitter runtime is a tag which identifies the purpose of this
  runtime; a Skitter worker would, for instance, use the mode `:worker`. Handlers
  determine how the local runtime handles connecting to runtimes with varying modes. A different
  handler can be set up for every possible mode. The local mode can be set with
  `set_local_mode/1`, handlers can be installed with `add_handler/2` and `set_default_handler/1`.
  Please refer to the documentation of these functions for more information.

  After a runtime has set up its mode and handlers, it can connect to other runtimes. This can be
  done with `connect/2`.
  """
  alias __MODULE__.{Beacon, Dispatcher, HandlerServer, HandlerSupervisor}

  @doc """
  Set the mode of the local runtime.

  The mode is a name which identifies the purpose the local runtime has in a Skitter cluster. It
  needs to be set in order to interact with other runtimes.
  """
  @spec set_local_mode(atom()) :: :ok
  def set_local_mode(mode) do
    Beacon.set_mode(mode)
  end

  @doc """
  Setup handlers.

  Handlers determine how the local runtime handles connections with Skitter runtimes
  with various modes. This function accepts a keyword list where each key is a mode, and each
  value is a module. When a runtime with a mode attempts to connect to the local runtime, the
  appropriate module will be called.

  To create a callback module, refer to `Skitter.Remote.Handler`
  """
  @spec setup_handlers(keyword()) :: :ok
  def setup_handlers(lst) do
    HandlerSupervisor.add_handlers(lst)
  end

  @doc """
  Attempt to connect to `remote`.

  This function verifies if `remote` is a valid Skitter node and tries to connect to it. If the
  connection is successful, this functions tries to find a bound handler for the local mode. If
  this works, `{:ok, mode}` is returned, where `mode` is the mode of the remote runtime.

  If the `expected_mode` argument is passed, `connect/2` only connects to the remote runtime if
  its mode is equal to `expected_mode`.

  The following errors may be returned if the connection does not succeed:
  - `{:error, :uninitialized_local}`: the local node is not set up properly (`set_local_mode/1`
  has not been called)
  - `{:error, :not_distributed}`: the local node is not alive according to `Node.alive?/0`
  - `{:error, :not_connected}`: it was not possible to connect to the remote runtime
  - `{:error, :not_skitter}`: the remote node is not a Skitter remote
  - `{:error, :incompatible}`: the remote node is running an incompatible version of Skitter
  - `{:error, :uninitialized_remote}`: the remote node does not have a mode
  - `{:error, :mode_mismatch}`: the mode of the remote runtime is not equal to `expected_mode`
  - `{:error, :unknown_mode}`: the remote or local runtime does not have a handler for the mode of
  the other runtime.
  - The handler of the local mode may return a custom `{:error, reason}` tuple.
  """
  @spec connect(node()) :: {:ok, atom()} | {:error, any()}
  def connect(remote, expected_mode \\ nil) do
    with {:ok, local_mode} <- Beacon.verify_local(),
         {:ok, remote_mode} <- Beacon.verify_remote(remote),
         :ok <- verify_mode(remote_mode, expected_mode),
         {:ok, handler} <- Dispatcher.dispatch(Node.self(), remote_mode, {:accept, remote}) do
      case Dispatcher.dispatch(remote, local_mode, {:accept, Node.self()}) do
        {:ok, _} ->
          {:ok, remote_mode}

        {:error, reason} ->
          HandlerServer.remove(handler, remote)
          {:error, reason}
      end
    else
      tup -> tup
    end
  end

  defp verify_mode(_remote, nil), do: :ok
  defp verify_mode(expected, expected), do: :ok
  defp verify_mode(_, _), do: {:error, :mode_mismatch}
end
