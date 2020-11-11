# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Master.Application do
  @moduledoc false
  use Application
  require Logger

  alias Skitter.Remote
  alias Skitter.Master.{Config, WorkerConnection}

  def start(:normal, []) do
    children = [
      Skitter.Master.ManagerSupervisor,
      Skitter.Master.WorkerConnection.Supervisor
    ]

    {:ok, sup} = Supervisor.start_link(children, strategy: :rest_for_one)
    setup_remote()
    {:ok, sup}
  end

  defp setup_remote() do
    Remote.set_local_mode(:master)
    Remote.setup_handlers(worker: WorkerConnection.Handler)

    case WorkerConnection.connect(Config.get(:workers, [])) do
      {:error, reasons} ->
        Logger.error("Could not connect with some workers: #{inspect(reasons)}")
        System.stop(1)

      :ok ->
        :ok
    end
  end
end
