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

  The skitter_remote application relies on `mode` and `handlers` configuration, which is set
  through an application-specific config.exs file. When this template is `use`d, a setting for
  `mode` and `handlers` may be provided, which will override the application configuration. If
  no setting is provided for `mode` or `handlers`, the configuration will not be modified.

  After the tests have been run, the original `mode` and `handlers` configuration will be
  restored.

  ## State Reset

  The `:skitter_remote` application heavily relies on global state for dispatching messages to
  `:handlers`. While testing, it is often required to spawn custom handlers, which mess up this
  global state.

  In order to prevent this, the state of the `:skitter_remote` programs is reset between tests.

  ## Remotes

  It is often required to test functionality with actual remote runtimes. This can be done through
  the use of the `:distributed` tag. The following situations are possible:

  - The test is not marked as distributed (i.e. there is no tag); in this case `Node.stop/0` is
    called before the test to ensure it behaves as if the local node was never distributed.
  - The test is marked as distributed (`@tag :distributed`); in this case, the node is distributed
    (with `Cluster.ensure_distributed/0`)
  - The test is marked as distributed and a list is passed along with the tag. In this case, a
    remote is spawned for each key in the list. `Skitter.Remote.Test.Cluster.spawn_node/3` is used
    to achieve this. The created node is added to the test context with the key as its name.
    Furthermore, the node is killed when the test completes.  A list or a tuple can be passed as a
    value to the key. When a list of `{module, function, args}` is passed,
    `Skitter.Remote.Test.rpc/4` is called on the remote for each module, function, args tuple.
    This is useful to execute arbitrary code on the remote host. A two-element tuple can be passed
    instead of a list. The first item of this tuple is a list of `{module, function args}` tuples,
    which will be used as before. The second item is a list of key-value pairs that can be used to
    configure the `skitter_remote` application.

  To facilitate the creation of remotes, the remotes will automatically inherit the configuration
  of the current node. Furthermore, options passed to `use` with the `remote_opts` key will be
  automatically set for all created nodes. The options passed as an argument take priority over
  those passed to `use`.
  """
  use ExUnit.CaseTemplate

  defp local_configuration_block(opts) do
    if opts[:mode] || opts[:handlers] do
      test_mode = Keyword.get(opts, :mode)
      test_handlers = Keyword.get(opts, :handlers)

      quote do
        setup_all do
          original_mode = Application.fetch_env!(:skitter_remote, :mode)
          original_handlers = Application.fetch_env!(:skitter_remote, :handlers)

          Application.put_env(:skitter_remote, :mode, unquote(test_mode))
          Application.put_env(:skitter_remote, :handlers, unquote(test_handlers))

          on_exit(fn ->
            Application.put_env(:skitter_remote, :mode, original_mode)
            Application.put_env(:skitter_remote, :handlers, original_handlers)
            reset_remote_app()
          end)

          :ok
        end
      end
    end
  end

  defp state_reset_block(_) do
    quote do
      setup do
        reset_remote_app()
        :ok
      end
    end
  end

  defp remote_block(opts) do
    default_remote_opts = Keyword.get(opts, :remote_opts, [])

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
            Enum.map(lst, &setup_remote/1)
        end
      end

      defp setup_remote({name, rpcs}) when is_list(rpcs), do: setup_remote({name, {rpcs, []}})

      defp setup_remote({name, {rpcs, remote_opts}}) do
        remote_opts = unquote(default_remote_opts) ++ remote_opts
        opts = Enum.map(remote_opts, fn {key, value} -> {:skitter_remote, key, value} end)

        remote = Cluster.spawn_node(name, :skitter_remote, opts)
        Enum.each(rpcs, fn {m, f, a} -> Cluster.rpc(remote, m, f, a) end)
        on_exit(fn -> Cluster.kill_node(remote) end)
        {name, remote}
      end
    end
  end

  using opts do
    quote do
      alias Skitter.Remote.Test.Cluster

      defp reset_remote_app do
        Application.stop(:skitter_remote)
        Application.start(:skitter_remote)
      end

      unquote(local_configuration_block(opts))
      unquote(state_reset_block(opts))
      unquote(remote_block(opts))
    end
  end
end
