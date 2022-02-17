# Copyright 2018 - 2022, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Worker do
  @moduledoc """
  This module defines a GenServer that specifies the behaviour of Skitter Workers.
  """
  use GenServer, restart: :transient

  use Skitter.Telemetry, prefix: :worker
  alias Skitter.Runtime.ComponentStore
  require Skitter.Runtime.ComponentStore

  defstruct [:component, :strategy, :context, :idx, :ref, :state, :tag]

  def start_link(args), do: GenServer.start_link(__MODULE__, args)
  def deploy_complete(pid), do: GenServer.cast(pid, :sk_deploy_complete)

  @impl true
  def init({context = %{_skr: {:deploy, _, _}}, state, tag}), do: {:ok, {context, state, tag}}
  def init({context, state, tag}), do: {:ok, init_state({context, state, tag})}

  @impl true
  def handle_cast(:sk_deploy_complete, {context, state, tag}) do
    context = update_in(context._skr, fn {:deploy, ref, idx} -> {ref, idx} end)
    {:noreply, init_state({context, state, tag})}
  end

  def handle_cast({:sk_msg, msg, inv}, srv), do: {:noreply, process_hook(msg, inv, srv)}
  def handle_cast(:sk_stop, srv), do: {:stop, :normal, srv}

  @impl true
  def handle_info(msg, srv), do: {:noreply, process_hook(msg, :external, srv)}

  defp init_state({context, state, tag}) when is_function(state, 0) do
    init_state({context, state.(), tag})
  end

  defp init_state({context, state, tag}) do
    {ref, idx} = context._skr

    Telemetry.emit([:init], %{}, %{pid: self(), ref: ref, idx: idx, tag: tag})

    %__MODULE__{
      component: context.component,
      strategy: context.strategy,
      context: %{context | deployment: ComponentStore.get(:deployment, ref, idx)},
      state: state,
      idx: idx,
      ref: ref,
      tag: tag
    }
  end

  defp process_hook(msg, inv, srv) do
    Telemetry.wrap([:process], %{pid: self(), message: msg, invocation: inv}) do
      state = srv.strategy.process(%{srv.context | invocation: inv}, msg, srv.state, srv.tag)
      %{srv | state: state}
    end
  end
end
