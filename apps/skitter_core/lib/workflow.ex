# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Workflow do
  @moduledoc """
  Data processing pipeline.

  A reactive workflow is a collection of connected `Skitter.Element` (i.e.
  components or workflows) which make up a data processing pipeline. This module
  defines the internal representation of a skitter workflow as an elixir struct,
  as well as the `Access` behaviour which allows one to access and modify the
  elements inside a workflow.
  """
  alias Skitter.{Port, Instance, Strategy}

  @behaviour Access

  @typedoc """
  Internal workflow representation.

  A workflow is a directed acyclic graph where each node is a named
  `t:Instance.t/0`. Connections between nodes are stored as a map of
  `t:address/0`. Like a component, a workflow has in -and out ports and an
  optional name.
  """
  @type t :: %__MODULE__{
          name: module() | nil,
          in_ports: [Port.t(), ...],
          out_ports: [Port.t()],
          # TODO: rename this?
          nodes: %{optional(id()) => Instance.t()},
          links: %{required(address()) => [address()]},
          strategy: Strategy.t()
        }

  defstruct name: nil,
            in_ports: [],
            out_ports: [],
            nodes: %{},
            links: %{},
            strategy: nil

  @typedoc """
  Identifier of a node in a workflow.
  """
  @type id() :: atom()

  @typedoc """
  Address of a port in a workflow.

  An address can refer to a `t:Skitter.Port.t/0` of a node in the workflow, or
  to a port of the workflow itself.

  An address is a tuple which identifies a node in the workflow, and a port of
  this node. When the address refers to a workflow port, the node name is
  replaced by `nil`.

  Note that it is possible for an in -and out port in a workflow to share an
  address.
  """
  @type address() :: {id() | nil, Port.t()}

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

  ignore_empty([:out_ports])
  ignore_short([:handler, :nodes, :links])

  describe(:in_ports, "in")
  describe(:out_ports, "out")
end
