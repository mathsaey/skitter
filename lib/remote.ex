defmodule Skitter.Remote do
  @moduledoc """
  Facilities to interact with remote Skitter runtimes.

  This module offers facilities to query Skitter about the available remote Skitter runtimes and
  their properites. It also defines various functions which can be used to spawn Skitter workers
  on remote Skitter nodes.
  """
  alias __MODULE__.{Beacon, Handler, Registry, Tags}
  alias __MODULE__.TaskSupervisor, as: Sup

  # ---------- #
  # Connecting #
  # ---------- #

  @typedoc """
  Worker tag.

  A worker may be started with a tag, which indicates properties of the node. For instance, a
  `:gpu` tag could be added to a node which has a gpu. Various functions in this module can be
  used to only spawn workers on nodes with given tags.
  """
  @type tag :: atom()

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
    local_mode = Beacon.mode()

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

  # ----------------- #
  # Local Information #
  # ----------------- #

  @doc "Get the name of the current Skitter runtime."
  @spec self() :: node()
  def self(), do: Node.self()

  @doc "Get the name of the master node of the cluster."
  @spec master() :: node()
  def master(), do: Registry.master()

  @doc "Get a list of the names of all the worker runtimes in the cluster."
  @spec workers() :: [node()]
  def workers(), do: Registry.workers()

  @doc "Get a list of all the worker runtimes tagged with a given `t:tag/0`."
  @spec with_tag(tag()) :: [node()]
  def with_tag(tag), do: Tags.workers_with(tag)

  @doc "Get a list of all the tags of `node()`."
  @spec tags(node()) :: [tag()]
  def tags(node), do: Tags.of_worker(node)

  @doc "Check if the local runtime is connected to the specified remote runtime."
  @spec connected?(node()) :: boolean()
  def connected?(node), do: Registry.connected?(node)

  # ---------------- #
  # Remote Execution #
  # ---------------- #

  @doc """
  Execute `mod.func(args)` on every specified remote runtime, obtain results in a list.
  """
  @spec on_many([node()], module(), atom(), [any()]) :: [{node(), any()}]
  def on_many(remotes, mod, func, args) do
    remotes
    |> Enum.map(&{&1, Task.Supervisor.async({Sup, &1}, mod, func, args)})
    |> Enum.map(fn {n, t} -> {n, Task.await(t)} end)
  end

  @doc """
  Execute `fun` on every specified remote runtime, obtain results in a list.
  """
  @spec on_many([node()], (() -> any())) :: [{node(), any()}]
  def on_many(remotes, fun) do
    remotes
    |> Enum.map(&{&1, Task.Supervisor.async({Sup, &1}, fun)})
    |> Enum.map(fn {n, t} -> {n, Task.await(t)} end)
  end

  @doc """
  Execute `mod.func(args)` on `remote`, block until a result is available.
  """
  @spec on(node(), module(), atom(), [any()]) :: any()
  def on(remote, mod, func, args), do: on_many([remote], mod, func, args) |> hd() |> elem(1)

  @doc """
  Execute `fun` on `remote`, block until a result is available.
  """
  @spec on(node(), (() -> any())) :: any()
  def on(remote, fun), do: on_many([remote], fun) |> hd() |> elem(1)

  @doc """
  Execute a function on every worker runtime.

  The result of each worker will be returned in a keyword list of `{worker, result}` pairs.
  """
  @spec on_all_workers(module(), atom(), [any()]) :: [{node(), any()}]
  def on_all_workers(mod, func, args), do: on_many(Registry.workers(), mod, func, args)

  @doc """
  Execute a function on every worker runtime.

  The result of each worker will be returned in a keyword list of `{worker, result}` pairs.
  """
  @spec on_all_workers((() -> any())) :: [{node(), any()}]
  def on_all_workers(fun), do: on_many(Registry.workers(), fun)

  @doc """
  Execute a function on every core on every worker runtime.

  A list of results will be returned for each worker node. These results will be returned in a
  keyword list of `{worker, result}` pairs.
  """
  @spec on_all_worker_cores((() -> any())) :: [{node(), [any()]}]
  def on_all_worker_cores(fun), do: on_all_workers(fn -> core_times(fun) end)

  @doc """
  Execute a function n times on every worker runtime.

  A list of results will be returned for each worker node. These results will be returned in a
  keyword list of `{worker, result}` pairs.
  """
  @spec n_times_on_all_workers(pos_integer(), (() -> any())) :: [{node(), [any()]}]
  def n_times_on_all_workers(n, fun), do: on_all_workers(fn -> n_times(n, fun) end)

  @doc """
  Execute a function on every worker runtime tagged with `tag`.

  The result of each worker will be returned in a keyword list of `{worker, result}` pairs.
  """
  @spec on_tagged_workers(tag(), (() -> any())) :: [{node(), any()}]
  def on_tagged_workers(tag, fun), do: on_many(Tags.workers_with(tag), fun)

  @doc """
  Execute a function on every core on every worker runtime tagged with `tag`.

  The result of each worker will be returned in a keyword list of `{worker, result}` pairs.
  """
  @spec on_tagged_worker_cores(tag(), (() -> any())) :: [{node(), any()}]
  def on_tagged_worker_cores(tag, fun), do: on_tagged_workers(tag, fn -> core_times(fun) end)

  @doc """
  Execute a function n times, distributed over the available workers.

  This is handy when you wish to create n workers distributed over the cluster. The work to be
  done will be divided over the worker nodes in a round robin fashion. This behaviour may change
  in the future.
  """
  @spec on_n(pos_integer(), (() -> any())) :: [[any()]]
  def on_n(n, fun) do
    workers()
    |> Enum.shuffle()
    |> Stream.cycle()
    |> Enum.take(n)
    |> Enum.frequencies()
    |> Enum.flat_map(fn {remote, times} ->
      on(remote, fn -> n_times(times, fun) end)
    end)
  end

  @spec n_times(pos_integer(), (() -> any())) :: [any()]
  defp n_times(n, fun), do: Enum.map(1..n, fn _ -> fun.() end)

  @spec core_times((() -> any())) :: [any()]
  defp core_times(fun), do: n_times(System.schedulers_online(), fun)
end
