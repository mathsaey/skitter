# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Test.Cluster do
  require Logger

  alias Skitter.Runtime.Configuration

  @hostname "127.0.0.1"
  @nodename "skitter_test_node"
  @fullname :"#{@nodename}@#{@hostname}"
  @hostname_charlst to_charlist(@hostname)

  @moduledoc """
  Provide support for distributed skitter tests.

  Based on: https://github.com/phoenixframework/phoenix_pubsub/blob/master/test/support/cluster.ex
  """

  # Remote Functionality
  # --------------------

  @doc """
  Spawn a master node with `name` which will automatically connect to `workers`
  """
  def spawn_master(name \\ :test_master, options \\ []) do
    spawn_node(name, :master, options)
  end

  @doc """
  Spawn a worker for each element in `lst`.

  The workers will be named based on the values in `lst`.
  """
  def spawn_workers(lst) do
    lst
    |> Enum.map(&{&1, :worker, []})
    |> spawn_nodes()
  end

  @doc """
  Kill a node.
  """
  def kill_node(node), do: :slave.stop(node)

  @doc """
  Execute function `func` of module `mod` with `args` on node `n`.
  """
  def rpc(n, mod, func, args \\ []), do: :rpc.block_call(n, mod, func, args)

  # Local Functionality
  # -------------------

  @doc """
  Restore the runtime to the default setup for testing
  """
  def load_default, do: load_with(default_options())

  @doc """
  Reload the skitter runtime with specific `options`.

  Only the `mode`, `worker_nodes`, `master_node` and `automatic_connect`
  configuration may be provided. `mode` is mandatory. This function will raise
  if there is an issues with the provided options.
  """
  def load_with(options) do
    mode = check_options(options)

    # Silence the logger while we stop the skitter runtime
    level = Logger.level()
    Logger.configure(level: :warn)
    Application.stop(:skitter)
    Logger.configure(level: level)

    if mode == :local, do: Node.stop(), else: ensure_distributed()

    for {key, val} <- options, do: Configuration.put_env(key, val)
    Application.ensure_all_started(:skitter)
  end

  def check_options(options) do
    # Ensure mode is present and valid
    {options, mode} =
      case Keyword.pop(options, :mode) do
        {nil, _} ->
          raise "`mode` option is mandatory for `load_with`."

        {mode, lst} when mode in [:local, :master, :worker] ->
          {lst, mode}

        {invalid, _} ->
          raise "Invalid mode for `load_with`: `#{inspect(invalid)}`"
      end

    allowed = [:worker_nodes, :master_node, :automatic_connect]
    options = Enum.reduce(allowed, options, &Keyword.delete(&2, &1))

    unless Enum.empty?(options) do
      raise "Invalid options for `load_with`: `#{inspect(options)}`"
    end

    mode
  end

  defp default_options do
    [
      mode: :local,
      worker_nodes: [],
      master_node: false,
      automatic_connect: false
    ]
  end

  # Local Setup
  # -----------

  defp distribute_local do
    Node.start(@fullname)
    :erl_boot_server.start([@hostname_charlst])
  end

  defp cluster_ready?, do: Node.alive?() and Node.self() == @fullname
  defp ensure_distributed, do: unless(cluster_ready?(), do: distribute_local())

  # Remote setup
  # ------------

  defp spawn_nodes(list) do
    list
    |> Enum.map(fn {n, m, o} -> Task.async(fn -> spawn_node(n, m, o) end) end)
    |> Enum.map(&Task.await(&1))
  end

  def spawn_node(name, mode, extra_opts) do
    ensure_distributed()

    {:ok, node} = :slave.start(@hostname_charlst, name, spawn_args())

    add_code_paths(node)
    transfer_configuration(node)

    start_skitter(node, mode, extra_opts)
    node
  end

  defp add_code_paths(n), do: rpc(n, :code, :add_paths, [:code.get_path()])

  defp transfer_configuration(node) do
    for {app_name, _, _} <- Application.loaded_applications() do
      for {key, val} <- Application.get_all_env(app_name) do
        rpc(node, Application, :put_env, [app_name, key, val])
      end
    end
  end

  defp start_skitter(node, mode, extra_opts) do
    for {k, v} <- extra_opts do
      rpc(node, Application, :put_env, [:skitter, k, v])
    end

    rpc(node, Application, :put_env, [:skitter, :mode, mode])
    rpc(node, Application, :ensure_all_started, [:skitter])
  end

  defp spawn_args do
    to_charlist(
      "-loader inet -hosts #{@hostname} -setcookie #{Node.get_cookie()}"
    )
  end
end
