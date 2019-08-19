# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Instance do
  @moduledoc """
  Runtime representation of a `t:Skitter.Element.t/0` after deployment.
  """
  alias Skitter.Element

  defstruct elem: nil, ref: nil

  @typedoc """
  Instance representation.

  An instance is defined by the element it instantiates and a unique reference
  to the runtime representation of the element returned by its handler.
  """
  @type t :: %__MODULE__{elem: Element.t(), ref: any()}
end

defimpl Inspect, for: Skitter.Instance do
  import Inspect.Algebra

  def inspect(inst, opts) do
    container_doc("#Instance<", Map.to_list(inst), ">", opts, &doc/2)
  end

  defp doc({:__struct__, _}, _), do: empty()
  defp doc({:ref, s}, opts), do: to_doc(s, opts)

  defp doc({:elem, e = %{name: nil}}, opts), do: to_doc(e, opts)
  defp doc({:elem, %{name: name}}, opts), do: to_doc(name, opts)
end
