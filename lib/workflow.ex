# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Workflow do
  @moduledoc """
  Data processing pipeline.

  A reactive workflow is a collection of connected workflows and components. Together, these
  workflows and components make up a data processing pipeline. This module defines the internal
  representation of a skitter workflow as an elixir struct, as well as the `Access` behaviour
  which allows one to access and modify the elements inside a workflow.
  """
  alias Skitter.{Component, Port}

  @behaviour Access

  @typedoc """
  Internal workflow representation.

  A workflow is a directed acyclic graph where each node is a tuple containing a
  `t:Skitter.Component.t()` or `t:Skitter.Workflow.t()` along with initialisation arguments.
  Connections between nodes are stored as a map of `t:address/0`. Like a component, a workflow has
  in -and out ports and an optional name.
  """
  @type t :: %__MODULE__{
          name: module() | nil,
          in: [Port.t(), ...],
          out: [Port.t()],
          # TODO: rename this?
          nodes: %{optional(id()) => {Component.t() | t(), [any()]}},
          links: %{required(id()) => %{required(Port.t()) => [{id(), Port.t()}]}}
        }

  defstruct name: nil,
            in: [],
            out: [],
            nodes: %{},
            links: %{}

  @typedoc """
  Identifier of a node in a workflow.
  """
  @type id() :: atom()

  # --------- #
  # Utilities #
  # --------- #

  @impl true
  def fetch(wf, key), do: Access.fetch(wf.nodes, key)

  @impl true
  def pop(wf, key) do
    {val, nodes} = Access.pop(wf.nodes, key)
    {val, %{wf | nodes: nodes}}
  end

  @impl true
  def get_and_update(wf, key, f) do
    {val, nodes} = Access.get_and_update(wf.nodes, key, f)
    {val, %{wf | nodes: nodes}}
  end
end

defimpl Inspect, for: Skitter.Workflow do
  use Skitter.Inspect, prefix: "Workflow", named: true

  ignore_empty([:out])
  ignore_short([:handler, :nodes, :links])
end
