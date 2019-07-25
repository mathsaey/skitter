# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Configuration do
  @moduledoc false
  # Module to set and retrieve skitter configuration parameters + documentation
  # of available configuration settings.
  #
  # Notes:
  #   - `put_env/2` can be used by command line parsers and other setup scripts
  #   - Each setting "accessor" should have a sane default
  #   - _Never_ modify these values after the Skitter application has started

  @doc """
  Add a value to skitters application environment.

  This function should only be used in application start up scripts and test
  setup code.
  """
  @spec put_env(atom(), any()) :: :ok
  def put_env(key, value) do
    Application.put_env(:skitter, key, value, persistent: true)
  end

  @doc """
  Determines which mode a skitter node starts in.

  The supported modes are `master`, `worker`, and `local` (the default).

  A skitter master node is responsible for delegating work to the various
  workers nodes in a skitter cluster. A master node cannot perform any work
  when no worker nodes are available.

  Worker nodes are responsible for the actual execution of a workflow, they
  receive work from a master node.

  Finally, the local mode enables users to experiment with skitter workflows
  without the hassle of setting up the master and worker nodes. It is primarily
  intended for development.
  """
  @spec mode() :: :local | :master | :worker
  def mode, do: get_env(:mode, :local)

  @doc """
  Location of the skitter standard library.

  If this is `nil`, no standard library files will be loaded.
  Note that the runtime will not load the standard library in `:worker` mode.
  """
  @spec standard_library_path() :: Path.t() | nil
  def standard_library_path, do: get_env(:standard_library_path, nil)

  @doc """
  Which worker nodes to automatically connect to, only used in `master` mode.

  Defaults to the empty list.

  The `nodes` configuration is only used by a skitter node which is running as a
  master. This option should contain a list of hostnames of a set of worker
  nodes. While starting the skitter application, the master node will attempt to
  connect to the provided worker nodes. Thus, the worker nodes should be online
  before a master node is started with a list of nodes.

  Nodes can also be added at runtime through the use of
  `Skitter.Runtime.add_node/1`.
  """
  @spec worker_nodes() :: [node()]
  def worker_nodes, do: get_env(:worker_nodes, [])

  @doc """
  Which master to connect to, only used in `worker` mode.

  Defaults to false.

  This settings causes a worker to connect to a master node specified as the
  value of this option. If the node cannot connect to the master, no error
  is raised. However, if the master is reachable, and if it enabled the
  `automatic_connect/0` setting, it will automatically add the current node
  as a worker.

  This setting is primarily intended to allow workers to reconnect to their
  master after failure.
  """
  @spec master_node() :: node() | false
  def master_node, do: get_env(:master_node, false)

  @doc """
  Specify if profiling should be enabled, and for how long.

  This option specifies an amount of time (in seconds) the current skitter node
  should profile its execution using `:fprof`. The output of fprof will be
  stored in the current working directory with the name `<nodename>.profile`.
  When this option is false, profiling is disabled (the default).
  """
  @spec profile() :: boolean()
  def profile, do: get_env(:profile, false)

  @doc """
  Specify if skitter should automatically enable distribution.

  By default, skitter will automatically set itself up as a distributed erlang
  node with a name determined by its mode when it is running in `:master` or
  `:worker` mode. This setup is skipped if the erlang vm skitter is running on
  is already distributed (e.g. when the `--sname` or `--name` switch is provided
  to `elixir`). If you wish to start a skitter node which is not distributed,
  you can set `automatic_distribution` to `false`.
  """
  @spec automatic_distribution?() :: boolean()
  def automatic_distribution?, do: get_env(:automatic_distribution, true)

  @doc """
  Specify if skitter should automatically use connected nodes as workers.

  When this option is set to true (the default), skitter will automatically
  attempt to treat each node it is connected to (i.e. `Node.list()`) as a
  skitter worker node.

  When this option is set to false, skitter will only treat a connected node as
  a worker when `Skitter.Runtime.add_node/1` is called.

  This setting is mainly intended to enable unit tests to simulate node failure.
  Leave it at its default value if you're not sure what this does.
  """
  @spec automatic_connect?() :: boolean()
  def automatic_connect?, do: get_env(:automatic_connect, true)

  defp get_env(key, default), do: Application.get_env(:skitter, key, default)
end
