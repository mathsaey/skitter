# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Worker.Server do
  @moduledoc false
  use GenServer, restart: :transient

  defstruct [:comp, :state, :tag, :ctx]

  def start_link(lst = [_component, _context, _state, _tag]) do
    GenServer.start_link(__MODULE__, lst)
  end

  @impl true
  def init([comp, ctx, state, tag]) when is_function(state, 0) do
    {:ok, %__MODULE__{comp: comp, ctx: ctx, tag: tag}, {:continue, state}}
  end

  def init([comp, ctx, state, tag]) do
    {:ok, %__MODULE__{comp: comp, ctx: ctx, state: state, tag: tag}}
  end

  @impl true
  def handle_continue(state_fn, server_state) do
    {:noreply, %{server_state | state: state_fn.()}}
  end

  @impl true
  def handle_cast({:msg, m, i}, g = %__MODULE__{comp: comp, ctx: ctx, state: s, tag: t}) do
    {state, publish} = Skitter.Runtime.Strategy.receive(comp, ctx, m, i, s, t)
    Skitter.Runtime.send(ctx, publish, i)

    {:noreply, %{g | state: state}}
  end

  def handle_cast(:stop, state), do: {:stop, :normal, state}
end
