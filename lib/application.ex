# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Application do
  @moduledoc false
  require Logger
  use Application

  alias Skitter.Remote
  alias Skitter.Mode.{Master, Worker, Local}

  def start(:normal, []) do
    mode = Application.fetch_env!(:skitter, :mode)
    banner_or_log(mode)

    {:ok, pid} = sup(mode)

    case post_start(mode) do
      :ok -> {:ok, pid}
      any -> any
    end
  end

  defp sup(:worker) do
    Supervisor.start_link(
      [
        {Remote.Supervisor, [:worker, [master: Worker.MasterConnection]]}
      ],
      strategy: :one_for_one,
      name: __MODULE__
    )
  end

  defp sup(:master) do
    Supervisor.start_link(
      [
        {Remote.Supervisor, [:master, [worker: Master.WorkerConnection.Handler]]},
        Master.WorkerConnection.Supervisor
      ],
      strategy: :rest_for_one,
      name: __MODULE__
    )
  end

  defp sup(:local) do
    Supervisor.start_link(
      [],
      strategy: :one_for_one,
      name: __MODULE__
    )
  end

  defp post_start(:worker) do
    Worker.MasterConnection.connect()
    :ok
  end

  defp post_start(:master) do
    Master.WorkerConnection.connect()
    :ok
  end

  defp post_start(_), do: :ok

  # ------ #
  # Banner #
  # ------ #

  defp version, do: "v#{Application.spec(:skitter, :vsn)}"

  defp banner(mode) do
    logo =
      if IO.ANSI.enabled?() do
        "⬡⬢⬡⬢ #{IO.ANSI.italic()}Skitter#{IO.ANSI.reset()}"
      else
        "Skitter"
      end

    IO.puts("#{logo} #{version()} (#{mode} mode)\n")
  end

  defp logline(mode) do
    Logger.info("Skitter #{version()}")
    Logger.info("Starting in #{mode} mode")
  end

  defp banner_or_log(mode), do: if(IEx.started?(), do: banner(mode), else: logline(mode))
end
