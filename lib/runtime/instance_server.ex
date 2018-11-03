# Copyright 2018, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.InstanceServer do
  @moduledoc false

  use GenServer
  require Logger

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
    setup_logger(comp, id)
    Logger.debug "Started instance server"
    {:ok, nil, {:continue, {comp, init}}}
  end

  def handle_continue({comp, init}, nil) do
    {:ok, instance} = Skitter.Component.init(comp, init)
    Logger.debug "Finished initialization", state: inspect(instance.state)
    {:noreply, instance}
  end

  defp setup_logger(comp, id) do
    metadata = [
      identifier: id,
      component: comp,
    ]

    keys = [:pid] ++ Keyword.keys(metadata) ++ [:state, :args]

    Logger.metadata(metadata)
    Logger.configure_backend(:console, metadata: keys)
  end

  def handle_call({:react, args}, _, instance) do
    Logger.debug "React", args: inspect(args), state: inspect(instance.state)
    {:ok, instance, spits} = Skitter.Component.react(instance, args)
    Logger.debug "Finished reacting", state: inspect(instance.state)
    {:reply, {:ok, spits}, instance}
  end
end
