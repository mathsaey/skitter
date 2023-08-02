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

  def spawn_remote(context, state, tag, nil), do: spawn_random(context, state, tag)
  def spawn_remote(context, state, tag, on: node), do: spawn_on(node, context, state, tag)
  def spawn_remote(context, state, tag, with: ref), do: spawn_on(node(ref), context, state, tag)
  def spawn_remote(context, state, tag, tagged: ntag), do: spawn_tagged(ntag, context, state, tag)

  def spawn_remote(context, state, tag, avoid: ref) when is_pid(ref) do
    spawn_avoid(node(ref), context, state, tag)
  end

  def spawn_remote(context, state, tag, avoid: node) when is_atom(node) do
    spawn_avoid(node, context, state, tag)
  end

  def spawn_avoid(avoid, context, state, tag) do
    Remote.workers()
    |> List.delete(avoid)
    |> case do
      [] ->
        Logger.warning("Cannot avoid spawning worker on #{avoid}")
        spawn_random(context, state, tag)

      lst ->
        lst
        |> Enum.random()
        |> spawn_on(context, state, tag)
    end
  end

  def spawn_tagged(ntag, context, state, tag) do
    ntag
    |> Remote.with_tag()
    |> case do
      [] ->
        Logger.warning("No workers provide tag #{tag}")
        Remote.workers()

      lst ->
        lst
    end
    |> spawn_random(context, state, tag)
  end

  def spawn_random(context, state, tag), do: spawn_random(Remote.workers(), context, state, tag)

  def spawn_random(lst, context, state, tag) do
    lst |> Enum.random() |> spawn_on(context, state, tag)
  end

  def spawn_on(node, context, state, tag) do
    Remote.on(node, __MODULE__, :spawn_local, [context, state, tag])
  end

  def spawn_local(context, state, tag) do
    case Runtime.mode() do
      :master -> :error
      _ -> Skitter.Runtime.WorkerSupervisor.add_worker(context, state, tag)
    end
  end
end
