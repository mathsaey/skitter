# Copyright 2018 - 2022, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Worker do
  @moduledoc """
  This module defines a GenServer that specifies the behaviour of Skitter Workers.

  ## Worker Initialisation

  Workers that are created inside the deploy hook of a strategy may not perform any processing
  until they receive the `:sk_deploy_complete` message. This is done to avoid any processing being
  done before the entire workflow has finished deployment. It also ensures that the emit hook
  of downstream nodes in the workflow can not be called before their deployment is finished.

  The Skitter runtime guarantees that the `:sk_deploy_complete` message is sent in reverse
  topological order so that all the nodes downstream of a node are ready to receive data once a
  node activates.

  Before the deployment of a workflow is complete, the Skitter runtime sets the `_skr` field of
  the `t:Skitter.Strategy.Context/0` to `{:deploy, _, _}`. Thus, when a worker is spawned, it
  checks the value of this field to see if it can finish initialisation.

  Once deployment is completed, the `:_sk_deploy_complete` message is sent to all workers spawned
  by a strategy. This message indicates the worker may begin processing received messages. It is
  possible that workers receive messages before this point. This occurs when messages are sent
  inside the deploy hook. Intra-strategy messages may also be received by a worker before it
  receives the `:_sk_deploy_complete` hook. To ensure this does not cause issues, workers buffer
  all messages received before the initial `:_sk_deploy_complete`. When `:_sk_deploy_complete` is
  received, all these messages are processed in the order of arrival.
  """
  use GenServer, restart: :transient
  require Logger

  use Skitter.Telemetry
  alias Skitter.Runtime.NodeStore
  require Skitter.Runtime.NodeStore

  defstruct [:operation, :strategy, :context, :idx, :ref, :state, :role]

  def start_link(args), do: GenServer.start_link(__MODULE__, args)
  def deploy_complete(pid), do: GenServer.cast(pid, :sk_deploy_complete)

  @impl true
  def init({context = %{_skr: {:deploy, ref, idx}}, state, role}) do
    context = %{context | _skr: {ref, idx}}
    {:ok, {:uninitialized, [], srv_state(context, state, role, ref, idx)}}
  end

  def init({context, state, role}) do
    {ref, idx} = context._skr
    {:ok, srv_state(context, state, role, ref, idx)}
  end

  @impl true
  def handle_cast(:sk_deploy_complete, {:uninitialized, msgs, srv}) do
    srv = put_in(srv.context.deployment, NodeStore.get(:deployment, srv.ref, srv.idx))
    {:noreply, msgs |> Enum.reverse() |> Enum.reduce(srv, &process_hook/2)}
  end

  def handle_cast(:sk_deploy_complete, srv) do
    Logger.error("Initialized worker received :_sk_deploy_complete message")
    {:noreply, srv}
  end

  def handle_cast({:sk_msg, msg}, {:uninitialized, msgs, srv}) do
    {:noreply, {:uninitialized, [msg | msgs], srv}}
  end

  def handle_cast({:sk_msg, msg}, srv), do: {:noreply, process_hook(msg, srv)}
  def handle_cast(:sk_stop, state), do: {:stop, :normal, state}

  @impl true
  def handle_info(msg, srv), do: {:noreply, process_hook(msg, srv)}

  defp srv_state(context, state, role, ref, idx) when is_function(state, 0) do
    srv_state(context, state.(), role, ref, idx)
  end

  defp srv_state(context, state, role, ref, idx) do
    Telemetry.emit(
      [:worker, :init],
      %{},
      %{pid: self(), context: context, state: state, role: role}
    )

    %__MODULE__{
      operation: context.operation,
      strategy: context.strategy,
      context: context,
      state: state,
      ref: ref,
      idx: idx,
      role: role
    }
  end

  defp process_hook(msg, srv) do
    state =
      Telemetry.wrap [:hook, :process], %{
        pid: self(),
        context: srv.context,
        message: msg,
        state: srv.state,
        role: srv.role
      } do
        srv.strategy.process(srv.context, msg, srv.state, srv.role)
      end

    %{srv | state: state}
  end
end
