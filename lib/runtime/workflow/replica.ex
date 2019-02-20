# Copyright 2018, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Workflow.Replica do
  @moduledoc false

  use GenServer, restart: :transient

  require Logger

  alias __MODULE__, as: S

  alias Skitter.Workflow
  alias Skitter.Runtime.Component
  alias Skitter.Runtime.Workflow.Matcher

  defstruct [:workflow, :instances, :links, :matcher, :invocations]

  def start({ref, source_data}) do
    GenServer.start(__MODULE__, {ref, source_data})
  end

  def init(args) do
    {:ok, nil, {:continue, args}}
  end

  def handle_continue({ref, source_data}, nil) do
    workflow = Skitter.Runtime.Workflow.Store.get(ref)

    if Workflow.in_ports_match?(workflow.workflow, source_data) do
      {
        :noreply,
        %S{
          workflow: workflow.workflow,
          instances: workflow.instances,
          links: workflow.links,
          matcher: Matcher.new(),
          invocations: %{}
        },
        {:continue, source_data}
      }
    else
      Logger.error("Invalid source tokens for workflow", tokens: source_data)
      {:stop, :invalid_source_tokens}
    end
  end

  # Load the tokens to be processed
  def handle_continue(source_data, s = %S{}) do
    s
    |> process_sources(source_data)
    |> continue_if_active()
  end

  def handle_info({:react_finished, ref, spits}, s = %S{}) do
    {id, inv} = Map.pop(s.invocations, ref)

    s
    |> struct(invocations: inv)
    |> process_spits(spits, id)
    |> continue_if_active()
  end

  # When no more invocations are pending, the replica will receive no more
  # tokens. Therefore it can be safely halted.
  defp continue_if_active(s = %S{invocations: invocations, matcher: matcher}) do
    case {invocations == %{}, Matcher.empty?(matcher)} do
      {false, _} ->
        {:noreply, s}

      {true, true} ->
        {:stop, :normal, s}

      {true, false} ->
        # If the matcher is not empty a bug is present in the workflow
        Logger.error("Unused tokens in workflow", matcher: inspect(matcher))
        {:stop, :normal, s}
    end
  end

  # Token Processing
  # ----------------

  defp process_spits(s = %S{}, spits, from) do
    tokens =
      Enum.flat_map(spits, fn {out, val} ->
        dest_to_tokens(s, {from, out}, val)
      end)

    process_tokens(s, tokens)
  end

  defp process_sources(s = %S{}, sources) do
    tokens =
      Enum.flat_map(sources, fn {src, val} -> dest_to_tokens(s, src, val) end)

    process_tokens(s, tokens)
  end

  defp dest_to_tokens(%S{links: links}, destination, val) do
    Enum.map(Map.get(links, destination), fn {id, port} -> {id, port, val} end)
  end

  defp process_tokens(s = %S{}, lst) do
    Enum.reduce(lst, s, &process_token(&2, &1))
  end

  def process_token(s = %__MODULE__{matcher: m, instances: i}, t) do
    case Matcher.add(m, t, i) do
      {:ok, m} ->
        %{s | matcher: m}

      {:ready, m, id, args} ->
        {:ok, _, ref} = Component.react(i[id].ref, args)
        %{s | matcher: m, invocations: Map.put(s.invocations, ref, id)}
    end
  end
end
