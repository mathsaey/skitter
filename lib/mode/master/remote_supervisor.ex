# Copyright 2018 - 2021, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Mode.Master.RemoteSupervisor do
  @moduledoc false

  use Supervisor
  alias Skitter.{Remote, Mode.Master}

  def start_link([]) do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init([]) do
    children = [
      {Remote.Supervisor, [:master, [worker: Master.WorkerConnection.Handler]]},
      Master.WorkerConnection.Notifier
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
