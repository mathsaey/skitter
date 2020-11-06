defmodule Skitter.Remote do
  @moduledoc """
  Module to handle connecting to other Skitter runtimes.

  A Skitter cluster consists of various connected runtimes. This module contains the required
  abstractions to make the current node a "remote" node. I.e. using this module makes it possible
  to connect this runtime to other Skitter runtimes which use this module.

  Connecting to a remote runtime is done in two steps. First, it is verified if the remote node is
  compatible with the current node. Two nodes are compatible if they can connect to one another,
  if they are both Skitter remote nodes and if they have the same version. Afterwards, the runtime
  checks if the remote runtime has a handler for its "mode".

  Every Skitter runtime has a "mode", this mode is an atom which indicates its role in a Skitter
  cluster. The mode of a runtime is configured through the `:mode` key in the application
  environment of `:skitter_remote`. Using this module, Skitter runtimes can decide how to handle
  various remote modes.
  """
  alias __MODULE__.{Beacon, Dispatcher}

  @local_mode Application.compile_env(:skitter_remote, :mode)

  @doc """
  Bind the handling of `mode` to the calling process.

  When a compatible remote node uses `connect/1` to connect to this node, the current process will
  be notified **if** it has `mode` as its mode. The calling process should be a GenServer, as the
  notification will be sent using `GenServer.cast/2`. The process must use `GenServer.reply/2`
  to send a reply to the original process. The reply should be an `{:ok, pid}` tuple where pid
  refers to the current process if the connection is accepted and an `{:error, reason}` tuple if
  the connection is rejected.

  An example of a valid `handle_cast` is provided below:

  ```
  def handle_cast({:accept, from, _mode}, nil) do
    GenServer.reply(from, {:ok, self()})
    {:noreply, nil}
  end
  ```
  """
  @spec bind(atom()) :: :ok
  def bind(mode), do: Dispatcher.bind(mode)

  @doc """
  Bind the handling of unknown modes to the calling process.

  If a compatible remote node uses `connect/1` to connect to this node, the current process will
  be notified **if** there is no process which has used `bind_mode/1` on its mode. Thus, the
  calling process will act as a fallback process for unknown modes. Refer to `bind_mode/1` for
  additional explanation.
  """
  @spec bind_default() :: :ok
  def bind_default(), do: Dispatcher.default_bind()

  @doc """
  Attempt to connect to `remote`.

  This function verifies if `remote` is a valid Skitter node and tries to connect to it. If the
  connection is successful, this functions tries to find a bound handler for the local mode. If
  this works, `{:ok, mode, handler}` is returned. `mode` is the mode of the remote runtime, while
  `handler` is the pid of the handler which is bound to the mode of the local runtime on the
  remote system.

  The following errors may be returned if the connection does not succeed:
  - `{:error, :not_distributed}`: the local node is not alive according to (`Node.alive?/0`)
  - `{:error, :not_connected}`: it was not possible to connect to the remote runtime
  - `{:error, :not_skitter}`: the remote node is not a Skitter remote
  - `{:error, :incompatible}`: the remote node is running an incompatible version of Skitter
  - `{:error, :nomode}`: the remote node does not have a mode
  - `{:error, :unknown_mode}`: the remote runtime does not have a handler for the mode of the
    local runtime.
  - The handler of the local mode may return a custom `{:error, reason}` tuple.
  """
  @spec connect(node()) :: {:ok, atom(), pid()} | {:error, any()}
  def connect(remote) do
    with {:ok, mode} <- Beacon.verify_remote(remote),
         {:ok, handler} <- Dispatcher.dispatch(remote, @local_mode) do
      {:ok, mode, handler}
    else
      tup -> tup
    end
  end
end
