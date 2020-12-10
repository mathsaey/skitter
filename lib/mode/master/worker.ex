# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Mode.Master.Worker do
  @moduledoc false

  alias Skitter.Mode.Master.WorkerConnection

  alias Skitter.Runtime.Worker.{Server, Supervisor}
  alias Skitter.Runtime.Location

  def create(component, state, tag, _, constraints) do
    available = WorkerConnection.all() |> Location.resolve(constraints)

    node =
      case available do
        list when is_list(list) -> Enum.random(list)
        el -> el
      end

    {:ok, pid} =
      DynamicSupervisor.start_child(
        {Supervisor, node},
        {Server, [component, state, tag]}
      )

    pid
  end
end
