# Copyright 2018 - 2021, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0

defmodule Skitter.Runtime.WorkerSupervisor do
  @moduledoc false
  use DynamicSupervisor

  alias Skitter.Runtime.ConstantStore
  require Skitter.Runtime.ConstantStore

  def start_link(arg) do
    DynamicSupervisor.start_link(__MODULE__, arg)
  end

  @impl true
  def init(_arg) do
    DynamicSupervisor.init(strategy: :one_for_one, max_restarts: 0)
  end

  def add_worker(ctx = %{_skr: {ref, idx}}, state, tag) do
    pid = ConstantStore.get(:skitter_supervisors, ref, idx)
    {:ok, pid} = DynamicSupervisor.start_child(pid, {Skitter.Runtime.Worker, {ctx, state, tag}})
    pid
  end
end
