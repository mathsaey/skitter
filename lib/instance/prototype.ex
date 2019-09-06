# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Instance.Prototype do
  @moduledoc """
  Template to create a `Skitter.Instance`.

  A prototype is a template for the creation of a reactive component or
  workflow. It is defined by its element and its initialization arguments.
  Prototypes exist only before an element is deployed. At deployment time, a
  `Skitter.Handler` transforms the prototype into a `Skitter.Instance`.
  """
  alias Skitter.Element

  defstruct elem: nil, args: []

  @typedoc """
  Prototypes consist of `t:Skitter.Element.t/0` and initialization arguments.
  """
  @type t :: %__MODULE__{
    elem: Element.t(),
    args: [any()]
  }
end

defimpl Inspect, for: Skitter.Instance.Prototype do
  use Skitter.Inspect, prefix: "Prototype"

  ignore_short :args
  ignore_empty :args
  value_only [:args, :elem]
end
