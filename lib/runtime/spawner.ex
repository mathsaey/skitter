# Copyright 2018 - 2021, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Spawner do
  @moduledoc false
  require Logger

  alias Skitter.Runtime.{Config, Registry}

  def spawn(context, state, tag, nil), do: spawn_random(context, state, tag)
  def spawn(context, state, tag, on: node), do: spawn_remote(node, context, state, tag)
  def spawn(context, state, tag, with: ref), do: spawn_remote(node(ref), context, state, tag)
  def spawn(context, state, tag, tagged: ntag), do: spawn_tagged(ntag, context, state, tag)

  def spawn(context, state, tag, avoid: ref) when is_pid(ref) do
    spawn_avoid(node(ref), context, state, tag)
  end

  def spawn(context, state, tag, avoid: node) when is_atom(node) do
    spawn_avoid(node, context, state, tag)
  end

  def spawn(context, state, tag, :local) do
    case Config.get(:mode, :local) do
      :worker -> spawn_local(context, state, tag)
      :local -> spawn_local(context, state, tag)
      :master -> spawn_random(context, state, tag)
    end
  end

  def spawn_avoid(avoid, context, state, tag) do
    Registry.all()
    |> List.delete(avoid)
    |> case do
      [] ->
        Logger.warn("Cannot avoid spawning worker on #{avoid}")
        spawn_random(context, state, tag)

      lst ->
        lst
        |> Enum.random()
        |> spawn_remote(context, state, tag)
    end
  end

  def spawn_tagged(ntag, context, state, tag) do
    ntag
    |> Registry.with_tag()
    |> case do
      [] ->
        Logger.warn("No workers provide tag #{tag}")
        Registry.all()

      lst ->
        lst
    end
    |> spawn_random(context, state, tag)
  end

  def spawn_random(context, state, tag), do: spawn_random(Registry.all(), context, state, tag)

  def spawn_random(lst, context, state, tag) do
    lst |> Enum.random() |> spawn_remote(context, state, tag)
  end

  def spawn_local(context, state, tag) do
    Skitter.Runtime.WorkerSupervisor.add_worker(context, state, tag)
  end

  def spawn_remote(node, context, state, tag) do
    Skitter.Remote.on(node, __MODULE__, :spawn_local, [context, state, tag])
  end
end
