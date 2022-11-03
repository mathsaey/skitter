# Copyright 2018 - 2022, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Worker do
  @moduledoc """
  This module defines a GenServer that specifies the behaviour of Skitter Workers.
  """
  use GenServer, restart: :transient

  use Skitter.Telemetry
  alias Skitter.Runtime.NodeStore
  require Skitter.Runtime.NodeStore

  defstruct [:operation, :strategy, :context, :idx, :ref, :state, :tag]

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

  def handle_cast({:sk_msg, msg}, srv), do: {:noreply, process_hook(msg, srv)}
  def handle_cast(:sk_stop, srv), do: {:stop, :normal, srv}

  @impl true
  def handle_info(msg, srv), do: {:noreply, process_hook(msg, srv)}

  defp init_state({context, state, tag}) when is_function(state, 0) do
    init_state({context, state.(), tag})
  end

  defp init_state({context, state, tag}) do
    {ref, idx} = context._skr

    Telemetry.emit(
      [:worker, :init],
      %{},
      %{pid: self(), context: context, state: state, tag: tag}
    )

    %__MODULE__{
      operation: context.operation,
      strategy: context.strategy,
      context: %{context | deployment: NodeStore.get(:deployment, ref, idx)},
      state: state,
      idx: idx,
      ref: ref,
      tag: tag
    }
  end

  defp process_hook(msg, srv) do
    state =
      Telemetry.wrap [:hook, :process], %{
        pid: self(),
        context: srv.context,
        message: msg,
        state: srv.state,
        tag: srv.tag
      } do
        srv.strategy.process(srv.context, msg, srv.state, srv.tag)
      end

    %{srv | state: state}
  end
end
