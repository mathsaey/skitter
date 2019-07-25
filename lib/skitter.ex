# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter do
  # TODO: General overview
  @moduledoc """
  Component agnostic, reactive workflow system.

  ## Runtime application

  In order to do anything useful, the skitter runtime application should be
  started. This is automatically done if elixir is started with `mix run`,
  `mix skitter.master`, or `mix skitter.worker`.

  ### Errors

  The following errors can be returned if the skitter runtime application can
  not be started:

  - _Local nodes should not be distributed_: Returned when Skitter is started
  in `:local` `mode/0` on an elixir node with distribution enabled.
  - _Missing vm features_: Returned when the current version of the erlang VM
  doest not support all of the features required by skitter. Returned alongside
  a list of the modules that could not be loaded.
  - _Error connecting to nodes_: Returned when a Skitter runtime in `:master`
  `mode/0` could not connect to a specific worker node. This error is returned
  with a list of `{node, reason}` pairs. The potential values for `reason` are
  defined in `t:connection_error/0`
  """

  @typedoc """
  Available skitter runtime modes, see: `mode/0`
  """
  @type mode() :: :local | :master | :worker

  @typedoc """
  Errors that can be returned when connecting to a worker node.

  - `:connect_to_self` indicates the local node tried to connect to itself but
  failed. This is generally caused by a skitter master or working attempting to
  connect with itself.
  - `:invalid_node` indicates the remote node is not a skitter worker.
  - `:not_connected` indicates something went wrong when establishing the low
  level erlang connection.
  - `:not_distributed` indicates the local node is not distributed.
  - `:already_connected` indicates the current node is already connected to this
  worker.
  """
  @type connection_error() ::
          :connect_to_self
          | :invalid_node
          | :not_connected
          | :not_distributed
          | :already_connected
  @doc """
  Mode of the skitter runtime.

  A skitter virtual machine may be started in one of three modes: `:local`
  (the default), `:master`, or `:worker`.

  Nodes started in master node can access all of the language of skitter. i.e.,
  they can define workflows, components, and handlers. Besides this, master
  nodes have the ability to instantiate workflows, which will be deployed over
  the various worker nodes, and to send data records to instantiated workflows.
  A master cannot execute a workflow on its own, it needs to be connected to at
  least one worker node to do this.

  Worker nodes are responsible for the actual execution of a workflow, they
  receive work from a master node.

  Finally, local nodes can be used to develop and test skitter workflows. They
  are a hybrid of master and worker nodes. A skitter runtime is started in local
  mode by default.
  """
  @spec mode() :: mode()
  def mode, do: Skitter.Runtime.Configuration.mode()

  @doc """
  List the connected worker nodes.

  This function should only be called by a master node.
  """
  @spec connected_workers() :: [node()]
  def connected_workers, do: Skitter.Runtime.Nodes.all()

  @doc """
  Check the master of the node.
  """
  @spec connected_master() :: node() | nil
  def connected_master, do: Skitter.Runtime.Worker.master()

  @doc """
  Attempt to connect to a skitter worker node.

  Should only be used on a skitter runtime in master mode.
  Returns true if successful, otherwise, one of the following
  """
  @spec connect_to_worker(node()) :: :ok | {:error, connection_error()}
  def connect_to_worker(node), do: Skitter.Runtime.Nodes.connect(node)

  @doc """
  Attempt to connect to a skitter master node.

  Should only be used on a skitter runtime in worker mode.
  This function is useful to re-establish a connection to a master after a
  failure.
  """
  @spec connect_to_master(node()) :: :ok | {:error, connection_error()}
  def connect_to_master(node),
    do: Skitter.Runtime.Worker.connect_to_master(node)

  @doc """
  Load the file at `path`.

  The evaluation result of the file is returned.

  Note that a file can only be loaded once. This is done to prevent named
  components and workflows from being defined multiple times.
  If a previously loaded file is loaded again, the same value will be returned,
  even if the file has been modified in the meantime.
  """
  @spec load_file(Path.t()) :: any()
  def load_file(path), do: Skitter.Runtime.Loader.load(path)
end
