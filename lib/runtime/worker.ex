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

  When a strategy spawns several workers that communicate with each other, it is possible that
  workers do receive a message before they receive the `:_sk_deploy_complete` message. In this
  case, the worker is initialized on the spot and any future `:_sk_deploy_complete` messages are
  ignored.
  """
  use GenServer, restart: :transient

  use Skitter.Telemetry
  alias Skitter.Runtime.NodeStore
  require Skitter.Runtime.NodeStore

  defstruct [:operation, :strategy, :context, :idx, :ref, :state, :tag]

  def start_link(args), do: GenServer.start_link(__MODULE__, args)
  def deploy_complete(pid), do: GenServer.cast(pid, :sk_deploy_complete)

  @impl true
  def init({context = %{_skr: {:deploy, _, _}}, state, tag}) do
    {:ok, {:uninitialized, context, state, tag}}
  end

  def init({context, state, tag}) do
    {:ok, init_state({context, state, tag})}
  end

  @impl true
  def handle_cast(:sk_deploy_complete, state = {:uninitialized, _, _, _}) do
    {:noreply, activate_worker(state)}
  end

  def handle_cast(:sk_deploy_complete, srv), do: {:noreply, srv}

  def handle_cast({:sk_msg, msg}, state = {:uninitialized, _, _, _}) do
    srv = activate_worker(state)
    {:noreply, process_hook(msg, srv)}
  end

  def handle_cast({:sk_msg, msg}, srv), do: {:noreply, process_hook(msg, srv)}
  def handle_cast(:sk_stop, state), do: {:stop, :normal, state}

  @impl true
  def handle_info(msg, srv), do: {:noreply, process_hook(msg, srv)}

  defp activate_worker({:uninitialized, context, state, tag}) do
    context = update_in(context._skr, fn {:deploy, ref, idx} -> {ref, idx} end)
    init_state({context, state, tag})
  end

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
