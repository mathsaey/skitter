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
  import Inspect.Algebra

  def inspect(node, opts) do
    container_doc("#Node<", Map.to_list(node), ">", opts, &doc/2)
  end

  defp doc({:__struct__, _}, _), do: empty()

  defp doc({:args, []}, _), do: empty()
  defp doc({:args, lst}, opts), do: to_doc(lst, opts)

  defp doc({:elem, e = %{name: nil}}, opts), do: to_doc(e, opts)
  defp doc({:elem, %{name: name}}, opts), do: to_doc(name, opts)
end
