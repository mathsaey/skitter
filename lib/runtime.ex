# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime do
  @doc """
  Skitter runtime API.
  """

  alias __MODULE__
  alias __MODULE__.{Configuration, Registry, Profiler}

  # ------------- #
  # Runtime Setup #
  # ------------- #

  # Modules that should be provided by the erlang vm for Skitter to work.
  @required_features [:ets, :persistent_term]

  @doc """
  Start the Skitter runtime environment.

  Loads the Skitter runtime for the current
  `Skitter.Runtime.Configuration.mode/0`.  This function returns the same
  values as `c:Application.start/2`, i.e.  `{:ok, pid}` where `pid` refers to a
  supervisor. In certain circumstances, an `{:error, reason}` tuple is returned,
  these are documented below.

  This function is automatically called when Skitter is started as an elixir
  application. Thus, you should not need to call it yourself.

  ## Error values

  This function may return a `{:error, reason}` tuple. Any of the following
  reasons may be returned:

  - _Local nodes should not be distributed_: Returned when Skitter is started
  in `:local` mode on an elixir node with distribution enabled.
  - _Missing vm features_: Returned when the current version of the erlang VM
  doest not support all of the features required by skitter. Returned alongside
  a list of modules that should be included with the erlang runtime system.
  - _Error connecting to nodes_: Returned when a Skitter runtime in `:master`
  mode could not connect to a specific worker node. When this error is returned,
  it is returned along with either `:not_distributed` (which indicated the
  current node is not distributed), or a list of `{node, reason}` pairs, where
  `reason` is one of the following:
    - `:already_connected`: Already connected to this node
    - `:not_connected`: Connecting to the node failed.
    - `:invalid`: This node is not a skitter worker node.
  """
  def start do
    try do
      mode = Configuration.mode()
      nodes = Configuration.worker_nodes()

      check_vm_features()
      ensure_distribution_enabled(mode)

      # Profiler must be started before any processes are spawned
      if duration = Configuration.profile(), do: Profiler.profile(duration)

      # Mode-specific hooks + start/return supervision tree
      pre_load(mode, nodes)
      sup = shared_children() ++ children(mode)
      res = Supervisor.start_link(sup, strategy: :one_for_one, name: __MODULE__)
      post_load(mode, nodes)
      res
    catch
      :distributed_local -> {:error, "Local nodes should not be distributed"}
      {:vm_features_missing, lst} -> {:error, {"Missing vm features", lst}}
      {:connect_error, any} -> {:error, {"Error connecting to nodes", any}}
    end
  end

  # Mode-specific behaviour
  # -----------------------

  defp pre_load(:master, _), do: banner_if_iex()
  defp pre_load(:worker, nodes), do: warn_if_workers_not_empty(:worker, nodes)

  defp pre_load(:local, nodes) do
    if Node.alive?(), do: throw(:distributed_local)
    warn_if_workers_not_empty(:local, nodes)
    banner_if_iex()
  end

  defp post_load(atom, nodes) when atom in [:master, :local] do
    if Configuration.load_prelude?(), do: Skitter.Prelude._load()

    nodes =
      case atom do
        :master -> nodes
        :local -> Node.self()
      end

    case Runtime.Nodes.connect(nodes) do
      true -> nil
      :not_distributed -> throw {:connect_error, :not_distributed}
      any -> throw {:connect_error, any}
    end
  end

  defp post_load(:worker, _) do
    if master = Configuration.master_node(), do: Node.connect(master)
  end

  # Supervision Tree
  # ----------------

  def shared_children() do
    [{Task.Supervisor, name: Skitter.Runtime.TaskSupervisor}]
  end

  defp children(:master), do: [Registry, Runtime.Nodes.Supervisor]
  defp children(:worker), do: [Runtime.Worker]
  defp children(:local), do: children(:worker) ++ children(:master)

  # Utils
  # -----

  defp check_vm_features do
    missing =
      @required_features
      |> Enum.map(&{&1, Code.ensure_loaded?(&1)})
      |> Enum.reject(&elem(&1, 1))
      |> Enum.map(&elem(&1, 0))

    unless Enum.empty?(missing) do
      throw {:vm_features_missing, missing}
    end
  end

  defp ensure_distribution_enabled(:local), do: nil

  defp ensure_distribution_enabled(mode) do
    # Only perform this setup if the user did not start a distributed node
    unless Node.alive?() or !Configuration.automatic_distribution?() do
      # Erlang only start epmd ?automatically if the node is started as a
      # distributed node
      System.cmd("epmd", ["-daemon"])
      Node.start(mode, :shortnames)
    end
  end

  defp banner_if_iex do
    if IEx.started?(), do: IO.puts(banner())
  end

  defp banner do
    logo =
      if IO.ANSI.enabled?() do
        "#{IO.ANSI.italic()}⬡⬢⬡⬢ Skitter#{IO.ANSI.reset()}"
      else
        "Skitter"
      end

    "#{logo} (#{Application.spec(:skitter, :vsn)})"
  end

  defp warn_if_workers_not_empty(mode, workers) do
    mode = Atom.to_string(mode)

    unless Enum.empty?(workers) do
      IO.warn("Worker nodes are ignored in #{mode} mode!")
    end
  end
end
