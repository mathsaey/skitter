# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Component.PermanentInstance.Server do
  @moduledoc false

  use GenServer, restart: :transient

  defstruct [:id, :instance]

  def start_link({comp, init}) do
    GenServer.start_link(__MODULE__, {comp, init})
  end

  def init({comp, init}) do
    {:ok, nil, {:continue, {comp, init}}}
  end

  def handle_continue({comp, init}, nil) do
    {:ok, instance} = Skitter.Component.init(comp, init)
    state = %__MODULE__{id: make_ref(), instance: instance}
    {:noreply, state}
  end

  def handle_cast({:react, args, dst, ref}, s = %__MODULE__{instance: inst}) do
    {:ok, instance, spits} = Skitter.Component.react(inst, args)
    send(dst, {:react_finished, ref, spits})
    {:noreply, %{s | instance: instance}}
  end
end
