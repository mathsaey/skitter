# Copyright 2018 - 2021, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0

defmodule Skitter.Runtime.WorkerSupervisor do
  @moduledoc false
  # This supervisor supervises the various workers spawned for a component

  use DynamicSupervisor

  alias Skitter.{Strategy, Worker}
  alias Skitter.Runtime.ConstantStore
  require Skitter.Runtime.ConstantStore

  def start_link(arg) do
    DynamicSupervisor.start_link(__MODULE__, arg)
  end

  @impl true
  def init(_arg) do
    DynamicSupervisor.init(strategy: :one_for_one, max_restarts: 0)
  end

  @doc """
  Start a worker with `state` and `tag` for the given `ctx`.

  The appropriate supervisor will be selected based on the data captured in the context.
  """
  @spec add_worker(Strategy.context(), Worker.state(), Worker.tag()) :: Worker.ref()
  def add_worker(ctx, state, tag) do
    {ref, idx} =
      case ctx._skr do
        {:deploy, ref, idx} -> {ref, idx}
        {ref, idx} -> {ref, idx}
      end

    pid = ConstantStore.get(:skitter_supervisors, ref, idx)
    {:ok, pid} = DynamicSupervisor.start_child(pid, {Skitter.Runtime.Worker, {ctx, state, tag}})
    pid
  end

  @doc "Get a list of the workers for a given supervisor."
  @spec children(pid()) :: [pid()]
  def children(pid) do
    pid
    |> DynamicSupervisor.which_children()
    |> Enum.map(&elem(&1, 1))
  end
end
