# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Master.Manager do
  @moduledoc false
  use GenServer

  alias Skitter.Master.{ManagerSupervisor, Workers}

  alias Skitter.Runtime
  alias Skitter.Runtime.ImmutableStore

  @typedoc """
  Instance of a manager
  """
  @opaque t() :: %__MODULE__{name: pid(), name: module()}
  defstruct [:pid, :name]

  # --- #
  # API #
  # --- #

  @doc """
  Create a manager based on a workflow or component.
  """
  @spec create(Skitter.Element.t()) :: t()
  def create(element = %{name: name}) do
    {:ok, pid} = DynamicSupervisor.start_child(ManagerSupervisor, {__MODULE__, element})
    %__MODULE__{name: name, pid: pid}
  end

  @doc false
  def start_link(proto), do: GenServer.start_link(__MODULE__, proto)

  # ------ #
  # Server #
  # ------ #

  @impl true
  def init(element) do
    Workers.subscribe_up()

    if Workers.on_all(ImmutableStore, :store, [self(), element]) |> Enum.all?(&(&1 == :ok)) do
      {:ok, element}
    else
      {:stop, :store_failure}
    end
  end

  @impl true
  def handle_info({:worker_up, worker}, element) do
    case Runtime.on_remote(worker, ImmutableStore, :store, [self(), element]) do
      :ok -> {:noreply, element}
      _ -> {:stop, :store_failure, element}
    end
  end
end

defimpl Inspect, for: Skitter.Master.Manager do
  import Inspect.Algebra
  alias Skitter.Master.Manager

  def inspect(%Manager{name: nil}, _), do: "#Manager<>"
  def inspect(%Manager{name: name}, opts), do: concat(["#Manager<", to_doc(name, opts), ">"])
end
