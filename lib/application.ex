# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Application do
  @moduledoc false
  require Logger
  use Application

  alias Skitter.{Config, Remote, Runtime}
  alias Skitter.Mode.{Master, Worker, Local}

  def start(:normal, []) do
    mode = Application.fetch_env!(:skitter, :mode)

    with :ok <- pre_start(mode),
         {:ok, pid} <- sup(mode),
         :ok <- post_start(mode) do
      {:ok, pid}
    else
      any -> any
    end
  end

  defp sup(:worker) do
    Supervisor.start_link(
      [
        Runtime.DeploymentStore,
        Runtime.Worker.Supervisor,
        {Remote.Supervisor, [:worker, [master: Worker.MasterConnection]]}
      ],
      strategy: :one_for_one,
      name: __MODULE__
    )
  end

  defp sup(:master) do
    Supervisor.start_link(
      [
        Master.RemoteSupervisor,
        {Runtime.DeploymentStore, Master.DeploymentDistributor},
        Master.DeploymentDistributor,
        Master.ManagerSupervisor
      ],
      strategy: :one_for_one,
      name: __MODULE__
    )
  end

  defp sup(:local) do
    Supervisor.start_link(
      [
        Runtime.DeploymentStore,
        Runtime.Worker.Supervisor,
        Runtime.Manager.Supervisor
      ],
      strategy: :one_for_one,
      name: __MODULE__
    )
  end

  defp pre_start(:local) do
    banner(:local)
    Skitter.Worker.set_create_module(Local.Worker)
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
    Skitter.Worker.set_create_module(Master.Worker)
    Master.WorkerConnection.connect()
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
