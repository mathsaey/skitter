# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Worker do
  @moduledoc false
  use GenServer, restart: :transient

  defstruct [:dep_ref, :comp, :state, :tag, :wf_ref, :wf_id]

  def start_link(lst = [_component, _state, _tag]) do
    GenServer.start_link(__MODULE__, lst)
  end

  def send(ref, msg, inv), do: GenServer.cast(ref, {:msg, msg, inv})

  # Don't use GenServer.stop since it is synchronous
  def stop(ref), do: GenServer.cast(ref, :stop)

  @impl true
  def init([comp, state, tag]) when is_function(state, 0) do
    {:ok,
     %__MODULE__{
       dep_ref: comp._rt[:deployment_ref],
       wf_ref: comp._rt[:wf_ref],
       wf_id: comp._rt[:wf_id],
       comp: comp,
       tag: tag
     }, {:continue, state}}
  end

  def init([comp, state, tag]) do
    {:ok,
     %__MODULE__{
       dep_ref: comp._rt[:deployment_ref],
       wf_ref: comp._rt[:wf_ref],
       wf_id: comp._rt[:wf_id],
       comp: comp,
       state: state,
       tag: tag
     }}
  end

  @impl true
  def handle_continue(state_fn, server_state) do
    {:noreply, %{server_state | state: state_fn.()}}
  end

  @impl true
  def handle_cast({:msg, m, i}, g = %__MODULE__{dep_ref: d, comp: c, state: s, tag: t}) do
    {state, _publish} = Skitter.Runtime.Strategy.receive_message(c, d, i, m, s, t)
    {:noreply, %{g | state: state}}
  end

  def handle_cast(:stop, state), do: {:stop, :normal, state}
end
