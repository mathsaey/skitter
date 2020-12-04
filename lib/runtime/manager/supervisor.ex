# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Manager.Supervisor do
  @moduledoc false
  use DynamicSupervisor

  def start_link(hook) do
    DynamicSupervisor.start_link(__MODULE__, hook, name: __MODULE__)
  end

  @impl true
  def init([]), do: DynamicSupervisor.init(strategy: :one_for_one, extra_arguments: [nil])
  def init(hook), do: DynamicSupervisor.init(strategy: :one_for_one, extra_arguments: [hook])
end
