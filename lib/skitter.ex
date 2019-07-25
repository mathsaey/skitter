# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter do
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
  `mode/0` could not connect to a specific worker node. When this error is
  returned, it is returned along with either `:not_distributed` (which indicated
  the current node is not distributed), or a list of `{node, reason}` pairs,
  where `reason` is one of the following:
    - `:already_connected`: Already connected to this node
    - `:not_connected`: Connecting to the node failed.
    - `:invalid`: This node is not a skitter worker node.
  """

  @typedoc """
  Available skitter runtime modes, see: `mode/0`
  """
  @type mode() :: :local | :master | :worker

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
  def mode, do: Skitter.Configuration.mode()

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
