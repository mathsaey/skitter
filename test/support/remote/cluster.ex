# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Remote.Test.Cluster do
  @moduledoc """
  Provide support for distributed skitter tests.

  Based on: https://github.com/phoenixframework/phoenix_pubsub/blob/master/test/support/cluster.ex
  """
  @hostname "127.0.0.1"
  @nodename "skitter_test_node"
  @fullname :"#{@nodename}@#{@hostname}"
  @hostname_charlst to_charlist(@hostname)

  @doc """
  Spawn a node which will launch `app`.

  The node will be spawned with `name`, and will automatically start `app`.
  Loaded code and application configuration will be inherited from the local
  node. The current node will become distributed if needed.

  Any configuration passed in `extra_opts` will be set on the remote node,
  potentially overriding the configuration inherited from the local node.
  """
  def spawn_node(name, app, extra_opts) do
    ensure_distributed()

    {:ok, control, node} =
      :peer.start_link(%{
        name: name |> to_charlist() |> :peer.random_name(),
        host: @hostname_charlst,
        args: spawn_args()
      })

    add_code_paths(node)
    transfer_configuration(node)
    start_application(node, app, extra_opts)

    store_control(node, control)

    node
  end

  @doc """
  Kill a node.
  """
  def kill_node(node), do: node |> get_control() |> :peer.stop()

  @doc """
  Execute function `func` of module `mod` with `args` on node `n`.
  """
  def rpc(n, mod, func, args \\ []), do: :rpc.block_call(n, mod, func, args)

  @doc """
  Ensure the local node is distributed.
  """
  def ensure_distributed, do: unless(cluster_ready?(), do: distribute_local())

  # Local Setup
  # -----------

  defp distribute_local do
    Node.start(@fullname)
    :erl_boot_server.start([@hostname_charlst])
  end

  defp cluster_ready?, do: Node.alive?() and Node.self() == @fullname

  # We only need the control process when stopping a node.
  # We "hide" the pid of this process in an ets table and fetch it when stopping the node.
  defp store_control(node, control), do: Process.put(node, control)
  defp get_control(node), do: Process.get(node)

  # Remote setup
  # ------------

  defp add_code_paths(n), do: rpc(n, :code, :add_paths, [:code.get_path()])

  defp transfer_configuration(node) do
    for {app_name, _, _} <- Application.loaded_applications() do
      for {key, val} <- Application.get_all_env(app_name) do
        rpc(node, Application, :put_env, [app_name, key, val])
      end
    end
  end

  defp start_application(node, app, extra_opts) do
    for {a, k, v} <- extra_opts, do: rpc(node, Application, :put_env, [a, k, v])
    rpc(node, Application, :ensure_all_started, [app])
  end

  defp spawn_args do
    "-loader inet -hosts #{@hostname} -setcookie #{Node.get_cookie()}"
    |> String.split()
    |> Enum.map(&to_charlist/1)
  end
end
