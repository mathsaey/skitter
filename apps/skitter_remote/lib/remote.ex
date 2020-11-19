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
  @spec connect(node(), atom()) :: {:ok, atom()} | {:error, atom()}
  def connect(remote, expected_mode \\ nil) do
    local_mode = Application.fetch_env!(:skitter_remote, :mode)

    # This used to be a giant with block but it was hard to reason about, so we use a plug-like
    # pipeline to handle this instead.
    result =
      %{remote: remote, remote_mode: expected_mode, local_mode: local_mode}
      |> connect_and_verify()
      |> handle_local()
      |> handle_remote()

    case result do
      {:error, reason} -> {:error, reason}
      %{remote_mode: mode} -> {:ok, mode}
    end
  end

  defp connect_and_verify(attempt = %{remote: remote, remote_mode: expected}) do
    case {Beacon.verify_remote(remote), expected} do
      {{:ok, asked}, asked} -> attempt
      {{:ok, mode}, nil} -> Map.put(attempt, :remote_mode, mode)
      {{:ok, _}, _} -> {:error, :mode_mismatch}
      {{:error, reason}, _} -> {:error, reason}
    end
  end

  defp handle_local({:error, reason}), do: {:error, reason}

  defp handle_local(attempt = %{remote: remote, remote_mode: mode}) do
    case Handler.accept_local(mode, remote) do
      {:error, reason} -> {:error, reason}
      :ok -> attempt
    end
  end

  defp handle_remote({:error, reason}), do: {:error, reason}

  defp handle_remote(attempt = %{remote: remote, local_mode: mode}) do
    case Handler.accept_remote(remote, mode) do
      {:error, reason} ->
        Handler.remove(attempt[:remote_mode], remote)
        {:error, reason}

      :ok ->
        attempt
    end
  end

  @doc """
  Execute `mod.func(args)` on every specified remote runtime, obtain results in a list.
  """
  @spec on_many([node()], module(), atom(), [any()]) :: [any()]
  def on_many(remotes, mod, func, args) do
    remotes
    |> Enum.map(&Task.Supervisor.async({Skitter.Remote.TaskSupervisor, &1}, mod, func, args))
    |> Enum.map(&Task.await(&1))
  end

  @doc """
  Execute `fun` on every specified remote runtime, obtain results in a list.
  """
  @spec on_many([node()], (() -> any())) :: [any()]
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
