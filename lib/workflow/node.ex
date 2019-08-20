# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Workflow.Node do
  @moduledoc """
  `Skitter.Element` embedded in a reactive workflow.

  A node is the use of a reactive component or workflow inside a workflow.
  It is defined by its element and its initialization arguments. Workflow nodes
  exist only before a workflow is deployed. At deployment time, a
  `Skitter.Handler` transforms the node into a `Skitter.Instance`.
  """
  alias Skitter.Element

  defstruct elem: nil, args: []

  @typedoc """
  A node is defined by the `t:Skitter.Element.t/0` and initialization arguments.
  """
  @type t :: %__MODULE__{
    elem: Element.t(),
    args: [any()]
  }
end

defimpl Inspect, for: Skitter.Workflow.Node do
  use Skitter.Inspect, prefix: "Node"

  ignore_short :args
  ignore_empty :args
  value_only [:args, :elem]
end
