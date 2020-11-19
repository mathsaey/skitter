defmodule Skitter.Remote do
  @moduledoc false

  alias __MODULE__.{Beacon, Handler}

  @doc """
  Attempt to connect to `remote`.

  This function verifies if `remote` is a valid Skitter node and tries to connect to it. If the
  connection is successful, this functions tries to find a bound handler for the local mode. If
  this works, `{:ok, mode}` is returned, where `mode` is the mode of the remote runtime.

  If the `expected_mode` argument is passed, `connect/2` only connects to the remote runtime if
  its mode is equal to `expected_mode`.

  The following errors may be returned if the connection does not succeed:
  - `{:error, :not_distributed}`: the local node is not alive according to `Node.alive?/0`
  - `{:error, :not_connected}`: it was not possible to connect to the remote runtime
  - `{:error, :not_skitter}`: the remote node is not a Skitter remote
  - `{:error, :incompatible}`: the remote node is running an incompatible version of Skitter
  - `{:error, :mode_mismatch}`: the mode of the remote runtime is not equal to `expected_mode`
  - `{:error, :unknown_mode}`: the remote or local runtime does not have a handler for the mode of
  the other runtime.
  - The handler of the local mode may return a custom `{:error, reason}` tuple.
  """
  @spec connect(node()) :: {:ok, atom()} | {:error, any()}
  def connect(remote, expected_mode \\ nil) do
    local_mode = Application.fetch_env!(:skitter_remote, :mode)

    with {:ok, remote_mode} <- Beacon.verify_remote(remote),
         :ok <- verify_mode(remote_mode, expected_mode),
         :ok <- Handler.accept_local(remote_mode, remote) do
      case Handler.accept_remote(remote, local_mode) do
        :ok ->
          {:ok, remote_mode}

        {:error, reason} ->
          Handler.remove(remote_mode, remote)
          {:error, reason}
      end
    else
      tup -> tup
    end
  end

  defp verify_mode(_remote, nil), do: :ok
  defp verify_mode(expected, expected), do: :ok
  defp verify_mode(_, _), do: {:error, :mode_mismatch}

  @doc """
  Execute `mod.func(args)` on every specified remote runtime, obtain results in a list.
  """
  @spec on_many(node(), module(), atom(), [any()]) :: [any()]
  def on_many(remotes, mod, func, args) do
    remotes
    |> Enum.map(&Task.Supervisor.async({Skitter.Remote.TaskSupervisor, &1}, mod, func, args))
    |> Enum.map(&Task.await(&1))
  end

  @doc """
  Execute `fun` on every specified remote runtime, obtain results in a list.
  """
  @spec on_many(node(), (() -> any())) :: [any()]
  def on_many(remotes, fun) do
    remotes
    |> Enum.map(&Task.Supervisor.async({Skitter.Remote.TaskSupervisor, &1}, fun))
    |> Enum.map(&Task.await(&1))
  end

  @doc """
  Execute `mod.func(args)` on `remote`, block until a result is available.
  """
  @spec on(node(), module(), atom(), [any()]) :: any()
  def on(remote, mod, func, args), do: hd(on_many([remote], mod, func, args))

  @doc """
  Execute `fun` on `remote`, block until a result is available.
  """
  @spec on(node(), (() -> any())) :: any()
  def on(remote, fun), do: hd(on_many([remote], fun))
end
