# Copyright 2018 - 2022, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0

defmodule Skitter.Runtime.WorkflowManagerSupervisor do
  @moduledoc false
  # Supervisor which supervises workflow managers.

  use DynamicSupervisor
  alias Skitter.Runtime.WorkflowManager

  def start_link(arg), do: DynamicSupervisor.start_link(__MODULE__, arg, name: __MODULE__)

  @impl true
  def init(_arg), do: DynamicSupervisor.init(strategy: :one_for_one)

  def add_manager(ref) do
    DynamicSupervisor.start_child(__MODULE__, {WorkflowManager, ref})
  end

  def spawned_workflow_references do
    __MODULE__
    |> DynamicSupervisor.which_children()
    |> Enum.map(fn {_, pid, _, _} -> WorkflowManager.ref(pid) end)
  end
end
