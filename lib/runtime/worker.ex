# Copyright 2018 - 2021, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Worker do
  @moduledoc false

  use GenServer, restart: :transient
  alias Skitter.Runtime.ConstantStore
  require Skitter.Runtime.ConstantStore

  defstruct [:component, :strategy, :context, :idx, :ref, :links, :state, :tag]

  def start_link(args), do: GenServer.start_link(__MODULE__, args)
  def notify_deploy_complete(pid), do: GenServer.cast(pid, :sk_deployment_complete)

  @impl true
  def init({context = %{_skr: {:deploy, _, _}}, state, tag}), do: {:ok, {context, state, tag}}
  def init({context, state, tag}), do: {:ok, init_state({context, state, tag})}

  @impl true
  def handle_cast(:sk_deployment_complete, {context, state, tag}) do
    context = update_in(context._skr, fn {:deploy, ref, idx} -> {ref, idx} end)
    {:noreply, init_state({context, state, tag})}
  end

  def handle_cast({:sk_msg, msg, inv}, srv), do: {:noreply, recv_hook(msg, inv, srv)}
  def handle_cast(:sk_stop, srv), do: {:stop, :normal, srv}

  defp init_state({context, state, tag}) when is_function(state, 0) do
    init_state({context, state.(), tag})
  end

  defp init_state({context, state, tag}) do
    {ref, idx} = context._skr

    %__MODULE__{
      component: context.component,
      strategy: context.strategy,
      context: %{context | deployment: ConstantStore.get(:skitter_deployment, ref, idx)},
      links: ConstantStore.get(:skitter_links, ref, idx),
      state: state,
      idx: idx,
      ref: ref,
      tag: tag
    }
  end

  @impl true
  def handle_info(msg, srv), do: {:noreply, recv_hook(msg, :external, srv)}

  defp recv_hook(msg, inv, srv) do
    res = srv.strategy.receive(%{srv.context | invocation: inv}, msg, srv.state, srv.tag)
    res |> Keyword.drop([:state]) |> maybe_publish(srv, inv)

    case Keyword.fetch(res, :state) do
      {:ok, state} -> %{srv | state: state}
      :error -> srv
    end
  end

  defp maybe_publish([], _, _), do: nil

  defp maybe_publish([publish: lst], srv, invocation) do
    Enum.each(lst, fn {port, value} ->
      Enum.each(srv.links[port] || [], fn {ctx, port} ->
        ctx.strategy.send(%{ctx | invocation: invocation}, value, port)
      end)
    end)
  end

  defp maybe_publish([publish_with_invocation: lst], srv, _) do
    Enum.each(lst, fn {port, lst} ->
      Enum.each(srv.links[port] || [], fn {outer_ctx, port} ->
        Enum.each(lst, fn {val, inv} ->
          outer_ctx.strategy.send(%{outer_ctx | invocation: inv}, val, port)
        end)
      end)
    end)
  end
end
