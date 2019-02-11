# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Workflow.Master.Manager do
  @moduledoc false
  alias __MODULE__.{Server, Supervisor}

  def load(workflow) do
    DynamicSupervisor.start_child(Supervisor, {Server, workflow})
  end

  def react(manager, src_data) do
    GenServer.cast(manager, {:react, src_data})
  end
end
