# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Instance do
  @moduledoc """
  Runtime representation of a workflow or component after it has been deployed.
  """
  alias Skitter.{Component, Workflow}

  defstruct elem: nil, ref: nil

  @typedoc """
  Instance representation.

  An instance is defined by the element it instantiates (i.e. a component or
  workflow) and a unique reference to the runtime representation of an instance
  of this component or workflow. The exact nature of this reference is defined
  by the handler of the element.
  """
  @type t :: %__MODULE__{elem: Component.t() | Workflow.t(), ref: any()}
end

defimpl Inspect, for: Skitter.Instance do
  import Inspect.Algebra

  alias Skitter.Runtime.MetaHandler, as: Meta

  def inspect(inst, opts) do
    container_doc("#Instance<", Map.to_list(inst), ">", opts, &doc/2)
  end

  defp doc({:__struct__, _}, _), do: empty()
  defp doc({:ref, s}, opts), do: to_doc(s, opts)

  defp doc({:elem, Meta}, opts), do: to_doc(Meta, opts)
  defp doc({:elem, e = %{name: nil}}, opts), do: to_doc(e, opts)
  defp doc({:elem, %{name: name}}, opts), do: to_doc(name, opts)
end
