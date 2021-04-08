# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Remote.Test.Case do
  @moduledoc """
  Facilities for testing with remote nodes.

  This module provides an `ExUnit.CaseTemplate` which can spawn remote skitter runtimes in unit
  tests. It does this by automatically injecting several `ExUnit.Callbacks.setup/2` blocks. The
  various blocks are described in the following sections.

  ## Local Configuration

  While testing, skitter is set up in local mode. Using this case will automatically start the
  `Skitter.Remote.Supervisor` to ensure this node can connect to other nodes. A `mode` and
  `handlers` option can be provided to override the local mode and handlers. The spawned
  supervisor will be destroyed after the test has passed.

  ## Remotes

  It is often required to test functionality with actual remote runtimes. This can be done through
  the use of the `:remote` tag. When the tag is not present, `Node.stop/0` will be called to
  ensure the local node behaves as it it was never distributed. When it is present,
  `Cluster.ensure_distributed/0` is used to ensure the local node is distributed.

  A keyword list can be passed as an argument to this tag. For each key, value pair, a remote node
  will be spawned with `Cluster.spawn_node/3`. The value is another keyword list which can be used
  to customize the spawned node. The following options can be passed. Note that each of these
  options can also be passed to the `use` statement, in this case they will act as a default value
  if no value is passed.

  - `config:`, pass a keyword list. Each `{key, value}` pair will be added to the application
  environment of the remote skitter application.
  - `start_on_remote:`, pass a keyword list with a `mode` and a `handlers` (default to `[]`)
  pair. If this is provided, a skitter remote supervisor will be spawned on the remote node with
  the given mode and handlers. This can also be set to `false` to override the default value
  passed to `use`.
  - `rpc:` a list of `{module, function, args}` tuples, each mfa triplet in this list will be
  executed on the remote node using `Cluster.rpc/4`.

  The `Skitter.Remote.Test.Cluster` module is also aliased to `Cluster` when `use`ing this module.
  """
  use ExUnit.CaseTemplate
  alias Skitter.Remote.Test.Cluster

  using opts do
    quote do
      alias Skitter.Remote.Test.Cluster

      unquote(local_block(opts))
      unquote(remote_block(opts))
    end
  end

  defp local_block(opts) do
    mode = Keyword.get(opts, :mode, :test_mode)
    handlers = Keyword.get(opts, :handlers, [])

    quote do
      setup_all do
        Application.stop(:skitter)
        on_exit(fn -> Application.start(:skitter) end)
      end

      setup do
        start_supervised!({Skitter.Remote.Supervisor, [unquote(mode), unquote(handlers)]})
        :ok
      end
    end
  end

  def setup_remote({name, opts}, default_config, default_override) do
    config = Keyword.merge(default_config, Keyword.get(opts, :config, []))
    start = Keyword.get(opts, :start_on_remote, default_override)
    rpcs = Keyword.get(opts, :rpc, [])

    config = Enum.map(config, fn {key, value} -> {:skitter, key, value} end)
    remote = Cluster.spawn_node(name, :skitter, config)
    on_exit(fn -> Cluster.kill_node(remote) end)

    Enum.each(rpcs, fn {m, f, a} -> Cluster.rpc(remote, m, f, a) end)

    if start do
      Cluster.rpc(remote, Supervisor, :start_child, [
        {Skitter.Runtime.Application, remote},
        {Skitter.Remote.Supervisor, [start[:mode], start[:handlers] || []]}
      ])
    end

    {name, remote}
  end

  defp remote_block(opts) do
    default_config = opts[:remote_config] || []
    default_override = opts[:start_on_remote]

    quote do
      setup context do
        case context[:remote] do
          nil ->
            Node.stop()
            :ok

          true ->
            Cluster.ensure_distributed()
            :ok

          lst when is_list(lst) ->
            Enum.map(
              lst,
              &unquote(__MODULE__).setup_remote(
                &1,
                unquote(default_config),
                unquote(default_override)
              )
            )
        end
      end
    end
  end
end
