# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Component.Instance do
  @moduledoc """
  Use of a reactive component inside a workflow.

  A reactive component instance is the specific use of a reactive component
  inside of a reactive workflow. It is defined by its reactive component, its
  instantiation parameters and its links to other instances.
  """
  alias Skitter.Component

  defstruct component: nil, instantiation: []

  @typedoc """
  A component instance stores its component, instantiation parameters and its
  connections to the workflow.
  """
  @type t :: %__MODULE__{
          component: Component.t(),
          instantiation: [any()]
        }
end

defimpl Inspect, for: Skitter.Component.Instance do
  import Inspect.Algebra
  alias Skitter.Component

  def inspect(inst, opts) do
    container_doc("#Instance<", Map.to_list(inst), ">", opts, &doc/2)
  end

  defp doc({:__struct__, _}, _), do: empty()

  defp doc({:component, c = %Component{name: nil}}, opts), do: to_doc(c, opts)
  defp doc({:component, %Component{name: name}}, opts), do: to_doc(name, opts)

  defp doc({:instantiation, i}, opts), do: to_doc(i, opts)
end
