# Copyright 2018 - 2022, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Spawner do
  @moduledoc false
  # This module is responsible for spawning workers.

  require Logger

  alias Skitter.Runtime
  alias Skitter.Remote

  def spawn_remote(context, state, role, nil), do: spawn_random(context, state, role)
  def spawn_remote(context, state, role, on: node), do: spawn_on(node, context, state, role)
  def spawn_remote(context, state, role, with: ref), do: spawn_on(node(ref), context, state, role)
  def spawn_remote(context, state, role, tagged: tag), do: spawn_tagged(tag, context, state, role)

  def spawn_remote(context, state, role, avoid: ref) when is_pid(ref) do
    spawn_avoid(node(ref), context, state, role)
  end

  def spawn_remote(context, state, role, avoid: node) when is_atom(node) do
    spawn_avoid(node, context, state, role)
  end

  def spawn_avoid(avoid, context, state, role) do
    Remote.workers()
    |> List.delete(avoid)
    |> case do
      [] ->
        Logger.warning("Cannot avoid spawning worker on #{avoid}")
        spawn_random(context, state, role)

      lst ->
        lst
        |> Enum.random()
        |> spawn_on(context, state, role)
    end
  end

  def spawn_tagged(tag, context, state, role) do
    tag
    |> Remote.with_tag()
    |> case do
      [] ->
        Logger.warning("No workers provide tag #{tag}")
        Remote.workers()

      lst ->
        lst
    end
    |> spawn_random(context, state, role)
  end

  def spawn_random(context, state, role), do: spawn_random(Remote.workers(), context, state, role)

  def spawn_random(lst, context, state, role) do
    lst |> Enum.random() |> spawn_on(context, state, role)
  end

  def spawn_on(node, context, state, role) do
    Remote.on(node, __MODULE__, :spawn_local, [context, state, role])
  end

  def spawn_local(context, state, role) do
    case Runtime.mode() do
      :master -> :error
      _ -> Skitter.Runtime.WorkerSupervisor.add_worker(context, state, role)
    end
  end
end
