# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Remote.Test.ClusterCase do
  @moduledoc """
  Facilities for testing with remote nodes.

  This module provides an `Exunit.CaseTemplate` which faciliates working with
  cluster nodes in unit tests. It injects an `ExUnit.Callbacks.setup/2` which
  can automatically spawn cluster test nodes or disable distribution when
  appropriate.

  The injected `setup/2` callback handles 3 potential situations:

  - The test is marked as distributed (`@tag :distributed`); in this case,
    the node is distributed (with `Cluster.ensure_distributed/0`)
  - The test is not marked as distributed (i.e. there is no tag); in this case
    `Node.stop/0` is called before the test to ensure it behaves as if the
    local node was never distributed.
  - The test is marked as distributed, and a keyword list was passed along with
    the tag (`@tag distributed: [ key: [values], other: [values] ]`). In this
    case, `Skitter.Runtime.Test.Cluster.spawn_node/3` is called for every
    `key` in the list. `key` is passed as the name of the node, which will
    start the `:skitter_runtime` application. `setup/2` also guarantees the
    spawned cluster node is killed after the test is finished. `[values]` is
    expected to be a list which contains `{module, function, args}` tuples.
    `Skitter.Runtime.Test.Cluster.rpc/4` is called  on the created node for
    each tuple in the list. The created remote nodes are passed to the exunit
    context under the provided keys.
  """
  use ExUnit.CaseTemplate

  using _ do
    quote do
      alias Skitter.Remote.Test.Cluster

      setup context do
        if args = context[:distributed] do
          distributed(args)
        else
          not_distributed()
        end
      end

      defp not_distributed do
        Node.stop()
        :ok
      end

      defp distributed(true) do
        Cluster.ensure_distributed()
        :ok
      end

      defp distributed(lst) do
        for {name, rpcs} <- lst do
          remote = Cluster.spawn_node(name, :skitter_remote, [])
          on_exit(fn -> Cluster.kill_node(remote) end)

          for {mod, func, args} <- rpcs, do: Cluster.rpc(remote, mod, func, args)

          {name, remote}
        end
      end
    end
  end
end
