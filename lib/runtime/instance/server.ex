# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Instance.Server do
  use GenServer

  def start_link({id, comp, init}) do
    GenServer.start_link(__MODULE__, {id, comp, init})
  end

  def init({id, comp, init}) do
    {:ok, id, {:continue, {comp, init}}}
  end

  def handle_continue({comp, init}, id) do
    {:ok, instance} = Skitter.Component.init(comp, init)
    {:noreply, {instance, id}}
  end

  def handle_call({:react, args}, _, {instance, id}) do
    {:ok, instance, spits} = Skitter.Component.react(instance, args)
    {:reply, {:ok, spits}, {instance, id}}
  end

  def handle_call(:id, _, {instance, id}) do
    {:reply, id, {instance, id}}
  end
end
