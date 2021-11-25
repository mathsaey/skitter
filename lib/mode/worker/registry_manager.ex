# Copyright 2018 - 2021, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Mode.Worker.RegistryManager do
  @moduledoc false

  use GenServer

  alias Skitter.Remote
  alias Skitter.Runtime.Registry
  alias Skitter.Mode.Master.WorkerConnection.Notifier

  def start_link([]) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def master_up(remote), do: GenServer.cast(__MODULE__, {:master_up, remote})
  def master_down(remote), do: GenServer.cast(__MODULE__, {:master_down, remote})

  @impl true
  def init([]) do
    Registry.start_link()
    {:ok, :no_master}
  end

  @impl true
  def handle_cast({:master_up, remote}, :no_master) do
    :ok = Notifier.subscribe_up(remote)
    :ok = Notifier.subscribe_down(remote)

    remote
    |> Remote.on(Registry, :all_with_tags, [])
    |> Enum.each(fn {node, tags} -> Registry.add(node, tags) end)

    {:noreply, remote}
  end

  def handle_cast({:master_down, remote}, _) do
    :ok = Notifier.unsubscribe_up(remote)
    :ok = Notifier.unsubscribe_down(remote)
    Registry.remove_all()
    {:noreply, :no_master}
  end

  @impl true
  def handle_info({:worker_up, node, tags}, state) do
    Registry.add(node, tags)
    {:noreply, state}
  end

  @impl true
  def handle_info({:worker_down, node}, state) do
    Registry.remove(node)
    {:noreply, state}
  end
end
