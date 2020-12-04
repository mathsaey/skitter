# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Mode.Local.Worker do
  @moduledoc false

  alias Skitter.Runtime.{Worker, Worker.Supervisor}

  def create(component, state, tag, _, _) do
    {:ok, pid} = DynamicSupervisor.start_child(Supervisor, {Worker, [component, state, tag]})
    pid
  end
end
