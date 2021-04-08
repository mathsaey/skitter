# Copyright 2018 - 2021, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Worker do
  @moduledoc false

  use GenServer, restart: :transient

  alias Skitter.Runtime.ConstantStore
  require Skitter.Runtime.ConstantStore

  defstruct [:component, :strategy, :idx, :ref, :links, :state, :context, :tag]

  def start_link(args), do: GenServer.start_link(__MODULE__, args)

  @impl true
  def init({context, state, tag}) when is_function(state, 0) do
    {:ok, init_state(context, tag), {:continue, state}}
  end

  def init({context, state, tag}) do
    {:ok, %{init_state(context, tag) | state: state}}
  end

  @impl true
  def handle_continue(state_fn, srv) do
    {:noreply, %{srv | state: state_fn.()}}
  end

  @impl true
  def handle_cast({:sk_msg, msg, inv}, srv), do: {:noreply, recv_hook(msg, inv, srv)}
  def handle_cast(:sk_stop, srv), do: {:stop, :normal, srv}

  @impl true
  def handle_info(msg, srv), do: {:noreply, recv_hook(msg, :external, srv)}

  defp init_state(context, tag) do
    {ref, idx} = context._skr

    %__MODULE__{
      component: context.component,
      strategy: context.strategy,
      idx: idx,
      links: ConstantStore.get(:skitter_links, ref, idx),
      ref: ref,
      context: context,
      tag: tag
    }
  end

  defp recv_hook(msg, inv, srv) do
    %{strategy: str, context: cnt, ref: ref, idx: idx, tag: tag, state: state} = srv
    dep_data = ConstantStore.get(:skitter_deployment, ref, idx)
    res = str.receive(%{cnt | invocation: inv, deployment: dep_data}, msg, state, tag)

    res |> Keyword.drop([:state]) |> maybe_publish(srv)

    case Keyword.fetch(res, :state) do
      {:ok, state} -> %{srv | state: state}
      :error -> srv
    end
  end

  defp maybe_publish([], _), do: nil

  defp maybe_publish([publish: lst], %{links: links, context: ctx, ref: ref}) do
    Enum.each(lst, fn {port, value} ->
      links
      |> Keyword.get(port, [])
      |> Enum.each(fn {idx, port, comp, strat} ->
        context = %{
          ctx
          | strategy: strat,
            component: comp,
            deployment: ConstantStore.get(:skitter_deployment, ref, idx),
            _skr: {ref, idx}
        }

        strat.send(context, value, port)
      end)
    end)
  end

  defp maybe_publish([publish_with_invocation: lst], %{links: links, context: ctx, ref: ref}) do
    Enum.each(lst, fn {port, lst} ->
      links
      |> Keyword.get(port, [])
      |> Enum.each(fn {idx, port, comp, strat} ->
        context = %{
          ctx
          | strategy: strat,
            component: comp,
            deployment: ConstantStore.get(:skitter_deployment, ref, idx),
            _skr: {ref, idx}
        }

        Enum.each(lst, &strat.send(%{context | invocation: elem(&1, 1)}, elem(&1, 0), port))
      end)
    end)
  end
end
