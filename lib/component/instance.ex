# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Component.Instance do
  @moduledoc """
  Runtime representation of a component.
  """
  alias Skitter.Component

  defstruct component: nil, state_ref: nil

  @typedoc """
  Component instance representation.

  An instance is defined by its component, and a reference to its state.
  The type of this reference is defined by the handler of the component.
  """
  @type t :: %__MODULE__{
          component: Component.t(),
          state_ref: any()
        }
end

defimpl Inspect, for: Skitter.Component.Instance do
  import Inspect.Algebra

  alias Skitter.Component
  alias Skitter.Component.MetaHandler, as: Meta

  def inspect(inst, opts) do
    container_doc("#Instance<", Map.to_list(inst), ">", opts, &doc/2)
  end

  defp doc({:__struct__, _}, _), do: empty()

  defp doc({:component, Meta}, opts), do: to_doc(Meta, opts)
  defp doc({:component, c = %Component{name: nil}}, opts), do: to_doc(c, opts)
  defp doc({:component, %Component{name: name}}, opts), do: to_doc(name, opts)

  defp doc({:state_ref, s}, opts), do: to_doc(s, opts)
end
