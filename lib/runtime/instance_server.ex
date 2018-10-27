# Copyright 2018, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.InstanceServer do
  @moduledoc false

  @doc "Start an InstanceServer for a given component."
  @spec start_link(Skitter.Component.t(), any()) :: {:ok, pid()}
  def start_link(comp, init) do
    GenServer.start_link(__MODULE__.Server, {comp, init})
  end

  @doc "Make an InstanceServer react to data"
  @spec react(pid(), [any(), ...], timeout()) ::
          {:ok, [{Skitter.Component.port_name(), any()}]}
  def react(srv, args, timeout \\ :infinity) do
    GenServer.call(srv, {:react, args}, timeout)
  end

  defmodule Server do
    @moduledoc false
    use GenServer

    def init({comp, init}), do: {:ok, nil, {:continue, {comp, init}}}

    def handle_continue({comp, init}, nil) do
      {:ok, instance} = Skitter.Component.init(comp, init)
      {:noreply, instance}
    end

    def handle_call({:react, args}, _, instance) do
      {:ok, instance, spits} = Skitter.Component.react(instance, args)
      {:reply, {:ok, spits}, instance}
    end
  end
end
