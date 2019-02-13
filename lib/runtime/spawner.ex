# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Spawner do
  @moduledoc false
  use GenServer

  # --- #
  # API #
  # --- #

  def start_link(_) do
    GenServer.start(__MODULE__, [], name: __MODULE__)
  end

  def spawn_async(node, module, arg) do
    GenServer.cast({__MODULE__, node}, {:spawn, module, arg})
  end

  def spawn_sync(node, module, arg) do
    GenServer.call({__MODULE__, node}, {:spawn, module, arg})
  end

  # --------- #
  # GenServer #
  # --------- #

  def init(_), do: {:ok, nil}

  def handle_cast({:spawn, module, arg}, nil) do
    {:ok, _} = module.start(arg)
    {:noreply, nil}
  end

  def handle_call({:spawn, module, arg}, _, nil) do
    {:ok, pid} = module.start(arg)
    {:reply, {:ok, pid}, nil}
  end
end

