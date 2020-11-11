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
    setup_remote()

    children = [
      Skitter.Master.ManagerSupervisor,
      Skitter.Master.WorkerConnection.Supervisor
    ]

    {:ok, supervisor_pid} = Supervisor.start_link(children, strategy: :rest_for_one)

    case WorkerConnection.connect(Config.get(:skitter_master, [])) do
      :ok -> {:ok, supervisor_pid}
      {:error, reasons} -> {:error, reasons}
    end
  end

  defp setup_remote() do
    Remote.set_local_mode(:master)
    Remote.setup_handlers(worker: WorkerConnection.Handler)
  end
end
