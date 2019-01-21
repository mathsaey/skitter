# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Application do
  @moduledoc false

  use Application
  alias Skitter.Runtime
  import Skitter.Configuration

  def start(_type, []) do
    try do
      mode = get_env(:mode, :local)
      nodes = get_env(:worker_nodes, [])

      check_vm_features()
      ensure_distribution_enabled(mode)

      pre_load(mode, nodes)
      sup = shared_children() ++ children(mode)
      res = Supervisor.start_link(sup, strategy: :one_for_one, name: __MODULE__)
      post_load(mode, nodes)

      if duration = get_env(:profile) do
        Skitter.Profiler.profile(duration)
      end

      res
    catch
      {:vm_features_missing, lst} -> {:error, {"Missing vm features", lst}}
      {:connect_error, any} -> {:error, {"Error connecting to nodes", any}}
      {:local_error, any} -> {:error, {"Error starting local mode", any}}
    end
  end

  # Initialization Hooks
  # --------------------

  defp pre_load(:master, _), do: banner_if_iex()

  defp pre_load(:local, nodes) do
    put_env(:mode, :local)
    banner_if_iex()

    if not Enum.empty?(nodes) do
      IO.warn("Worker nodes are ignored in local mode")
    end
  end

  defp pre_load(_, _), do: nil

  defp post_load(:master, nodes) do
    case Skitter.Runtime.Nodes.connect(nodes) do
      true -> nil
      :not_distributed -> throw {:connect_error, :not_distributed}
      lst -> throw {:connect_error, lst}
    end
  end

  defp post_load(:local, _) do
    case Skitter.Runtime.Nodes.connect(Node.self()) do
      true -> nil
      any -> throw {:local_error, any}
    end
  end

  defp post_load(_, _), do: nil

  # Supervision Tree
  # ----------------

  def shared_children() do
    [
      {Task.Supervisor, name: Skitter.TaskSupervisor}
    ]
  end

  defp children(:worker), do: [Runtime.Worker.Supervisor]
  defp children(:master), do: [Runtime.Master.Supervisor]
  defp children(:local), do: children(:worker) ++ children(:master)

  # Utils
  # -----

  defp check_vm_features do
    missing =
      [:persistent_term, :ets]
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
    unless Node.alive?() or !get_env(:automatic_distribution, true) do
      # Erlang only start epmd automatically if the node is started as a
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
end
