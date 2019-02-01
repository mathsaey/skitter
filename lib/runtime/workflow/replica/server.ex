# Copyright 2018, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Workflow.Replica.Server do
  @moduledoc false

  use GenServer, restart: :transient

  require Logger

  alias __MODULE__, as: S

  alias Skitter.Workflow
  alias Skitter.Runtime.Component
  alias Skitter.Runtime.Workflow.Store
  alias Skitter.Runtime.Workflow.Replica.Matcher

  defstruct [:workflow, :matcher, :invocations]

  def start_link({workflow, source_data}) do
    GenServer.start(__MODULE__, {workflow, source_data})
  end

  def init(args) do
    {:ok, nil, {:continue, args}}
  end

  def handle_continue({workflow, source_data}, nil) do
    if Workflow.sources_match?(Store.get(workflow), source_data) do
      {
        :noreply,
        %S{workflow: workflow, matcher: Matcher.new(), invocations: %{}},
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
    |> process_spits(source_data, Store.get(s.workflow).sources)
    |> continue_if_active()
  end

  def handle_info({:react_finished, ref, spits}, s = %S{}) do
    {id, inv} = Map.pop(s.invocations, ref)

    s
    |> struct(invocations: inv)
    |> process_spits(spits, Store.get(s.workflow, id).links)
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

  defp process_spits(s = %S{}, spits, links) do
    process_tokens(s, spits_to_tokens(spits, links))
  end

  defp spits_to_tokens(spits, links) do
    Enum.flat_map(spits, fn {out, val} ->
      Enum.map(Access.get(links, out, []), fn {id, port} -> {id, port, val} end)
    end)
  end

  defp process_tokens(s = %S{}, []), do: s

  defp process_tokens(s = %S{}, [t | rest]) do
    s
    |> process_token(t)
    |> process_tokens(rest)
  end

  def process_token(s = %__MODULE__{matcher: matcher, workflow: wf}, token) do
    case Matcher.add(matcher, token, wf) do
      {:ok, matcher} ->
        %{s | matcher: matcher}

      {:ready, matcher, id, args} ->
        inst = Store.get(wf, id)
        {:ok, _, ref} = Component.react(inst.ref, args)
        %{s | matcher: matcher, invocations: Map.put(s.invocations, ref, id)}
    end
  end
end
