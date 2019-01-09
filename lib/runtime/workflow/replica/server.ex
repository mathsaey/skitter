# Copyright 2018, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Workflow.Replica.Server do
  @moduledoc false

  use GenServer, restart: :transient

  require Logger

  alias Skitter.Workflow
  alias Skitter.Runtime.Matcher

  def start_link(workflow, tokens) do
    GenServer.start(__MODULE__, {workflow, tokens})
  end

  # ------ #
  # Server #
  # ------ #

  # Verify the sources and start the replica server
  def init({workflow, tokens}) do
    setup_logger(workflow)

    if Workflow.sources_match?(workflow, tokens) do
      {:ok, {workflow, Matcher.new(), 0}, {:continue, tokens}}
    else
      {:stop, "Invalid tokens"}
    end
  end

  # Load the tokens to be processed
  def handle_continue(tokens, {workflow, matcher, pending}) do
    Enum.each(tokens, fn
      {source, value} ->
        destinations = Workflow.get_source!(workflow, source)

        Enum.each(destinations, fn destination ->
          # add_token(self(), value, destination)
        end)
    end)

    {:noreply, {workflow, matcher, pending}}
  end

  defp setup_logger(workflow) do
    metadata = [workflow: inspect(workflow)]
    keys = [:pid] ++ Keyword.keys(metadata) ++ [:tokens, :matcher]

    Logger.metadata(metadata)
  end

  # Invocation Tracking
  # -------------------
  # A workflow replica tracks the amount of active reacts, when this reaches
  # 0, no more work can occur.

  def handle_cast(:react_finished, {workflow, matcher, 1}) do
    unless Matcher.empty?(matcher) do
      Logger.error "Unused tokens in workflow", matcher: inspect(matcher)
    end

    {:stop, :normal, {workflow, matcher, 0}}
  end

  def handle_cast(:react_finished, {workflow, matcher, pending}) do
    {:noreply, {workflow, matcher, pending - 1}}
  end

  # Token Processing
  # ----------------

  def handle_cast({:token, token}, {workflow, matcher, pending}) do
    case Matcher.add(matcher, token, workflow) do
      {:ok, matcher} ->
        {:noreply, {workflow, matcher, pending}}

      {:ready, matcher, id, args} ->
        # TODO: react
        {:noreply, {workflow, matcher, pending + 1}}
    end
  end
end
