# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Mode.Master.ManagerSupervisor do
  @moduledoc false
  use Supervisor

  alias Skitter.Runtime.Manager
  alias Skitter.Mode.Master.WorkflowStoreDistributor

  def start_link([]) do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init([]) do
    children = [
      {Manager.Supervisor, &WorkflowStoreDistributor.distribute/1},
      WorkflowStoreDistributor.Supervisor
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
