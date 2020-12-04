# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.DeploymentStore do
  @moduledoc false
  use GenServer

  def start_link(hook) do
    GenServer.start_link(__MODULE__, hook, name: __MODULE__)
  end

  def add(ref, val), do: GenServer.cast(__MODULE__, {:add, ref, val})
  def del(ref), do: GenServer.cast(__MODULE__, {:del, ref})

  def get(ref) do
    [{^ref, v}] = :ets.lookup(__MODULE__, ref)
    v
  end

  def all, do: :ets.tab2list(__MODULE__)

  @impl true
  def init([]) do
    create_table()
    {:ok, nil}
  end

  def init(hook) do
    create_table()
    {:ok, hook}
  end

  defp create_table, do: :ets.new(__MODULE__, [:named_table, read_concurrency: true])

  @impl true
  def handle_cast({:add, ref, val}, hook) do
    :ets.insert(__MODULE__, {ref, val})
    GenServer.cast(hook, {:add, ref})
    {:noreply, hook}
  end

  def handle_cast({:del, ref}, hook) do
    :ets.delete(__MODULE__, ref)
    GenServer.cast(hook, {:del, ref})
    {:noreply, hook}
  end
end
