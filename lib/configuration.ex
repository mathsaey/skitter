# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Configuration do
  @moduledoc """
  Skitter application environment documentation and convenience functions.

  ## Configuration

  Skitter accepts the following configuration parameters:

  - `mode`
  - `nodes`
  - `automatic_distribution`

  ## Mode

  The `mode` configuration determines the mode a skitter node will start in.
  The supported modes are `master`, `worker`, and `local`.

  A skitter master node is responsible for delegating work to the various
  workers nodes in a skitter cluster. A master node cannot perform any work
  when no worker nodes are available.

  Worker nodes are responsible for the actual execution of a workflow, they
  receive work from a master node.

  Finally, the local mode enables users to experiment with skitter workflows
  without the hassle of setting up the master and worker nodes. It is primarily
  intended for development.

  You should not set the skitter mode manually, instead, rely on
  `Mix.Tasks.Skitter.Master` and `Mix.Tasks.Skitter.Worker` to start nodes in
  the correct mode for you. When no mode is provided, skitter will automatically
  start in local mode.

  ## Nodes

  The `nodes` configuration is only used by a skitter node which is running as a
  master. This option should contain a list of hostnames of a set of worker
  nodes. While starting the skitter application, the master node will attempt to
  connect to the provided worker nodes. Thus, the worker nodes should be online
  before a master node is started with a list of nodes.

  Nodes can also be added at runtime through the use of
  `Skitter.Runtime.add_node/1`.

  ## Automatic distribution

  By default, skitter will automatically set itself up as a distributed erlang
  node with a name determined by its mode when it is running in `:master` or
  `:worker` mode. This setup is skipped if the erlang vm skitter is running on
  is already distributed (e.g. when the `--sname` or `--name` switch is provided
  to `elixir`). If you wish to start a skitter node which is not distributed,
  you can set `automatic_distribution` to `false`.
  """

  @doc """
  Add a value to skitters application environment.
  """
  def put_env(key, value) do
    Application.put_env(:skitter, key, value, persistent: true)
  end

  @doc """
  Get a value from the skitter application environment.
  """
  def get_env(key, default \\ nil) do
    Application.get_env(:skitter, key, default)
  end
end
