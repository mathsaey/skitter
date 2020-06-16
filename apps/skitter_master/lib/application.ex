# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Master.Application do
  @moduledoc false
  use Application
  require Logger

  alias Skitter.Master

  def start(:normal, []) do
    children = [
      Master.Workers,
      Master.ManagerSupervisor
    ]

    {:ok, supervisor_pid} = Supervisor.start_link(children, strategy: :rest_for_one)

    :ok = try_connect()
    {:ok, supervisor_pid}
  end

  defp try_connect do
    case Master.Workers.connect(Master.get_env(:workers, [])) do
      :ok ->
        :ok

      {:error, reasons} ->
        Logger.error("Could not connect to workers: #{inspect(reasons)}")
        System.stop(1)
    end
  end
end
