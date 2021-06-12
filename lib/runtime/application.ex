# Copyright 2018 - 2021, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Application do
  @moduledoc false

  use Application
  require Logger

  alias Skitter.{Remote, Runtime}
  alias Skitter.Node.{Worker, Master}
  alias Skitter.Runtime.{Config, Registry}

  def start(:normal, []) do
    mode = Config.get(:mode, :local)

    with :ok <- pre_start(mode),
         {:ok, pid} <- start(mode),
         :ok <- post_start(mode) do
      {:ok, pid}
    else
      any -> any
    end
  end

  defp start(:local) do
    Supervisor.start_link(
      [
        {Task.Supervisor, name: Remote.TaskSupervisor},
        Runtime.WorkflowWorkerSupervisor,
        Runtime.WorkflowManagerSupervisor
      ],
      strategy: :rest_for_one,
      name: __MODULE__
    )
  end

  defp start(:master) do
    Supervisor.start_link(
      [
        Master.RemoteSupervisor,
        Runtime.WorkflowManagerSupervisor
      ],
      strategy: :one_for_one,
      name: __MODULE__
    )
  end

  defp start(:worker) do
    Supervisor.start_link(
      [
        Worker.RemoteSupervisor,
        Runtime.WorkflowWorkerSupervisor
      ],
      strategy: :one_for_one,
      name: __MODULE__
    )
  end

  # Tests take care of setting up their own supervisors as needed
  defp start(:test), do: Supervisor.start_link([], strategy: :one_for_one, name: __MODULE__)

  defp pre_start(:local) do
    banner(:local)
    :ok
  end

  defp pre_start(mode) do
    logline(mode)
    :ok
  end

  defp post_start(:worker) do
    Worker.MasterConnection.connect()
    :ok
  end

  defp post_start(:master) do
    Master.WorkerConnection.connect()
  end

  defp post_start(:local) do
    Registry.start_link()
    Registry.add(Node.self())
    :ok
  end

  defp post_start(_), do: :ok

  # ------ #
  # Banner #
  # ------ #

  defp version, do: "v#{Application.spec(:skitter, :vsn)}"

  defp banner(mode) do
    if Config.get(:banner, true) do
      logo =
        if IO.ANSI.enabled?() do
          "⬡⬢⬡⬢ #{IO.ANSI.italic()}Skitter#{IO.ANSI.reset()}"
        else
          "Skitter"
        end

      IO.puts("#{logo} (#{mode}) #{version()}\n")
    end
  end

  defp logline(mode) do
    Logger.info("Skitter #{version()}")
    Logger.info("Starting in #{mode} mode")
    if Node.alive?(), do: Logger.info("Reachable at `#{Node.self()}`")
  end
end
