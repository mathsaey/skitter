# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Mode.Local.WorkerSupervisor do
  @moduledoc false
  use DynamicSupervisor
  alias Skitter.Runtime.Worker

  def create(deployment, component, state, tag, _, _) do
    {:ok, pid} =
      DynamicSupervisor.start_child(__MODULE__, {Worker, [deployment, component, state, tag]})

    pid
  end

  def start_link([]) do
    DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
