# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Instance do
  @moduledoc """
  An instance represents the use of a workflow or component inside a workflow.

  An instance contains the element that is used, and the arguments that are passed along with it.
  """

  @typedoc """
  Element that is being instantiated and instantiation arguments.
  """
  @type t :: %__MODULE__{
          elem: Skitter.Component.t() | Skitter.Workflow.t(),
          args: [any()]
        }

  defstruct elem: nil, args: []
end

defimpl Inspect, for: Skitter.Instance do
  use Skitter.Inspect, prefix: "Instance"

  ignore_short(:args)
  ignore_empty(:args)
  value_only([:args, :elem])
end
