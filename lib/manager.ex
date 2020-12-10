# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Manager do
  @moduledoc """
  Manager for a deployed `Skitter.Workflow`
  """
  alias Skitter.Runtime.Manager.{Server, Supervisor}
  alias Skitter.{Workflow, Port}

  @opaque t :: %__MODULE__{pid: pid()}
  defstruct [:pid, :name]

  @spec create(Workflow.t()) :: t()
  def create(workflow) do
    {:ok, pid} = DynamicSupervisor.start_child(Supervisor, {Server, workflow})
    %__MODULE__{pid: pid, name: workflow.name}
  end

  @spec send(t(), [{Port.t(), any()}, ...]) :: :ok
  def send(%__MODULE__{pid: pid}, records), do: GenServer.cast(pid, {:data, records})

  @spec stop(t()) :: :ok
  def stop(%__MODULE__{pid: pid}), do: GenServer.stop(pid)
end

defimpl Inspect, for: Skitter.Manager do
  use Skitter.Inspect, prefix: "Manager", named: true

  ignore_empty(:pid)

  match(:pid, pid, _) do
    pid
    |> :erlang.pid_to_list()
    |> to_string()
    |> String.trim_leading("<")
    |> String.trim_trailing(">")
  end
end
