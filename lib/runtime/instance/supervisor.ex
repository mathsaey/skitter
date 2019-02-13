# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Instance.Supervisor do
  @moduledoc false
  alias Skitter.Runtime.{Component, Workflow, Instance}

  # A workflow should only crash when there is a programmer error present.
  # Therefore, it should never be automatically restarted.
  use Supervisor, restart: :temporary

  def start_link(workflow) do
    Supervisor.start_link(__MODULE__, workflow)
  end

  def init(workflow) do
    [Component, Workflow, Instance]
    |> Enum.flat_map(&(&1.child_specs(workflow)))
    |> Supervisor.init(strategy: :one_for_one)
  end
end
