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
  use Skitter.Inspect, prefix: "Instance"
  value_only([:ref, :elem])
end
