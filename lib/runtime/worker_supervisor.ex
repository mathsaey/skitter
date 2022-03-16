# Copyright 2018 - 2022, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0

defmodule Skitter.Runtime.WorkerSupervisor do
  @moduledoc """
  This supervisor manages the various workers spawned for a component

  ```
  + ------------------ +        + --------- +        + ------ +
  | ComponentWorkerSup | - n -> | WorkerSup | - n -> | Worker |
  + ------------------ +        + --------- +        + ------ +
  ```

  When a workflow is deployed, a `Skitter.Runtime.WorkerSupervisor` will be spawned for
  each component. This supervisor is responsible for managing the `Skitter.Runtime.Worker`s
  spawned by the strategy of the component.
  """
  use DynamicSupervisor, restart: :transient

  alias Skitter.{Strategy, Worker}
  alias Skitter.Runtime.ComponentStore

  require ComponentStore

  def start_link(arg), do: DynamicSupervisor.start_link(__MODULE__, arg)
  def stop(pid), do: DynamicSupervisor.stop(pid)

  @impl true
  def init(_arg), do: DynamicSupervisor.init(strategy: :one_for_one, max_restarts: 0)

  @doc """
  Start a worker with `state` and `tag` for the given `ctx`.

  The appropriate supervisor will be selected based on the data captured in the context.
  """
  @spec add_worker(Strategy.context(), Worker.state_or_state_fn(), Worker.tag()) :: Worker.ref()
  def add_worker(ctx, state, tag) do
    {ref, idx} =
      case ctx._skr do
        {:deploy, ref, idx} -> {ref, idx}
        {ref, idx} -> {ref, idx}
      end

    pid = ComponentStore.get(:local_supervisors, ref, idx)
    {:ok, pid} = DynamicSupervisor.start_child(pid, {Skitter.Runtime.Worker, {ctx, state, tag}})
    pid
  end

  def all_children(ref, idx, fun) when is_reference(ref) do
    ComponentStore.get(:local_supervisors, ref, idx)
    |> DynamicSupervisor.which_children()
    |> Enum.each(fn {_, pid, _, _} -> fun.(pid) end)
  end
end
