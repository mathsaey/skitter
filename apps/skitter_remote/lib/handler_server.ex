# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Remote.HandlerServer do
  @moduledoc false
  use GenServer
  alias Skitter.Remote.Dispatcher

  def start_link([module, mode]) do
    GenServer.start_link(__MODULE__, [module, mode])
  end

  def remove(server, remote) do
    GenServer.cast(server, {:remove, remote})
  end

  defp do_accept(remote, mode, module, state) do
    case module.accept_connection(remote, mode, state) do
      {:ok, state} ->
        Node.monitor(remote, true)
        {{:ok, self()}, state}

      {:error, reason, state} ->
        {{:error, reason}, state}
    end
  end

  defp do_remove(remote, module, state) do
    Node.monitor(remote, false)
    module.remove_connection(remote, state)
  end

  @impl true
  def init([module, mode]) do
    case mode do
      :default -> Dispatcher.default_bind()
      mode -> Dispatcher.bind(mode)
    end

    case module.init() do
      {:error, reason} -> {:error, reason}
      state -> {:ok, {module, state}}
    end
  end

  @impl true
  def handle_cast({:dispatch, {:accept, remote}, from, mode}, {module, state}) do
    {reply, state} = do_accept(remote, mode, module, state)
    GenServer.reply(from, reply)
    {:noreply, {module, state}}
  end

  def handle_cast({:dispatch, {:remove, remote}, from, mode}, {module, state}) do
    state = do_remove(remote, module, state)
    GenServer.reply(from, :ok)
    {:noreply, {module, state}}
  end

  def handle_cast({:remove, remote}, {module, state}) do
    state = do_remove(remote, module, state)
    {:noreply, {module, state}}
  end

  @impl true
  def handle_info({:nodedown, node}, {module, state}) do
    state = module.remote_down(node, state)
    {:noreply, {module, state}}
  end
end
