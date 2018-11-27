# Copyright 2018, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Master.NodeMonitorSupervisor do
  @moduledoc false
  use DynamicSupervisor

  # --- #
  # API #
  # --- #

  def start_link(_) do
    DynamicSupervisor.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def start_monitor(node) do
    spec = {Skitter.Runtime.Master.NodeMonitor, node}
    DynamicSupervisor.start_child(__MODULE__, spec)
  end

  # ---------- #
  # Supervisor #
  # ---------- #

  def init(nil) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
