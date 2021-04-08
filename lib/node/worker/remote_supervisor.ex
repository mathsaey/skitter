# Copyright 2018 - 2021, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Node.Worker.RemoteSupervisor do
  @moduledoc false
  use Supervisor
  alias Skitter.{Remote, Node.Worker}

  def start_link([]) do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init([]) do
    children = [
      {Remote.Supervisor, [:worker, [master: Worker.MasterConnection]]},
      Worker.RegistryManager
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
