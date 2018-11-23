# Copyright 2018, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Worker.Instance do
  @moduledoc false

  use GenServer

  # --- #
  # API #
  # --- #

  def start_link(comp, init, id \\ nil) do
    GenServer.start_link(__MODULE__, {comp, init, id})
  end

  def react(srv, args, timeout \\ :infinity) do
    GenServer.call(srv, {:react, args}, timeout)
  end

  # ------ #
  # Server #
  # ------ #

  def init({comp, init, id}) do
    {:ok, nil, {:continue, {comp, init}}}
  end

  def handle_continue({comp, init}, nil) do
    {:ok, instance} = Skitter.Component.init(comp, init)
    {:noreply, instance}
  end

  def handle_call({:react, args}, _, instance) do
    {:ok, instance, spits} = Skitter.Component.react(instance, args)
    {:reply, {:ok, spits}, instance}
  end
end
