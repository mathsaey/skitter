# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Component.PermanentInstance do
  @moduledoc false
  @behaviour Skitter.Runtime.Component.Instance

  use GenServer
  defstruct [:id, :instance]

  alias Skitter.Runtime.Nodes
  alias Skitter.Runtime.Spawner
  alias Skitter.Runtime.Component.Instance


  # --- #
  # API #
  # --- #

  def load(comp, init) do
    node = Nodes.select_permanent()
    {:ok, pid} = Spawner.spawn_sync(node, __MODULE__, {make_ref(), comp, init})
    {:ok, %Instance{mod: __MODULE__, ref: pid}}
  end

  def react(%Instance{ref: inst_ref}, args) do
    ref = make_ref()
    :ok = GenServer.cast(inst_ref, {:react, args, self(), ref})
    {:ok, inst_ref, ref}
  end

  # ------ #
  # Server #
  # ------ #

  def start({ref, comp, init}) do
    GenServer.start(__MODULE__, {ref, comp, init})
  end

  def init({ref, comp, init}) do
    {:ok, nil, {:continue, {ref, comp, init}}}
  end

  def handle_continue({ref, comp, init}, nil) do
    {:ok, instance} = Skitter.Component.init(comp, init)
    state = %__MODULE__{id: ref, instance: instance}
    {:noreply, state}
  end

  def handle_cast({:react, args, dst, ref}, s = %__MODULE__{instance: inst}) do
    {:ok, instance, spits} = Skitter.Component.react(inst, args)
    send(dst, {:react_finished, ref, spits})
    {:noreply, %{s | instance: instance}}
  end
end
