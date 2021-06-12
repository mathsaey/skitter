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

  def start(:normal, []), do: start(mode())
  def start_phase(:sk_welcome, :normal, []), do: welcome(mode())
  def start_phase(:sk_connect, :normal, []), do: connect(mode())

  defp mode, do: Skitter.Runtime.Config.get(:mode, :local)

  # Application Supervision Tree
  # ----------------------------

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

  # Banner / Log
  # ------------

  defp welcome(mode) do
    if IEx.started?() and Config.get(:banner, true), do: banner(mode), else: logline(mode)
    if Node.alive?(), do: Logger.info("Reachable at `#{Node.self()}`")
    :ok
  end

  defp version, do: "v#{Application.spec(:skitter, :vsn)}"
  defp logline(mode), do: Logger.info("Skitter #{version()} started in #{mode} mode")

  defp banner(mode) do
    logo =
      if IO.ANSI.enabled?() do
        "⬡⬢⬡⬢ #{IO.ANSI.italic()}Skitter#{IO.ANSI.reset()}"
      else
        "Skitter"
      end

    IO.puts("#{logo} #{version()} (#{mode})\n")
  end

  # Connect
  # -------

  defp connect(:worker) do
    Worker.MasterConnection.connect()
    :ok
  end

  defp connect(:master) do
    Master.WorkerConnection.connect()
  end

  defp connect(:local) do
    Registry.start_link()
    Registry.add(Node.self())
    :ok
  end

  defp connect(_), do: :ok
end
