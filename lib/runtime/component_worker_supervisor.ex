# Copyright 2018 - 2021, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0

defmodule Skitter.Runtime.ComponentWorkerSupervisor do
  @moduledoc false
  # This supervisor manages the supervisors spawned for each component.

  use Supervisor, restart: :temporary
  alias Skitter.Runtime.WorkerSupervisor

  def start_link(args), do: Supervisor.start_link(__MODULE__, args)

  @impl true
  def init({_ref, components}) do
    0..(components - 1)
    |> Enum.map(&Supervisor.child_spec({WorkerSupervisor, &1}, id: &1))
    |> Supervisor.init(strategy: :one_for_one, max_restarts: 0)
  end
end
