# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Instance do
  @moduledoc false
  alias __MODULE__
  defstruct [:pid]

  @doc """
  The children to be spawned for each loaded instance.
  """
  def child_specs(workflow), do: [{Instance.Manager.Server, workflow}]

  @doc """
  Create a new runtime instance from a workflow
  """
  def create(workflow) do
    {:ok, supervisor_pid} =
      DynamicSupervisor.start_child(
        Instance.CollectionSupervisor,
        {Instance.Supervisor, workflow}
      )

    {_, pid, _, _} =
      supervisor_pid
      |> Supervisor.which_children()
      |> Enum.find(&match?({Instance.Manager.Server, _, :worker, _}, &1))
    {:ok, %__MODULE__{pid: pid}}
  end

  def react(%__MODULE__{pid: pid}, data) do
    GenServer.cast(pid, {:react, data})
  end
end

defimpl Inspect, for: Skitter.Runtime.Instance do
  import Inspect.Algebra

  def inspect(inst, opts) do
    container_doc("#RuntimeInstance[", [inst.pid], "]", opts, &to_doc(&1, &2))
  end
end
