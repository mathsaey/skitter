# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Workflow.Node do
  @moduledoc """
  `Skitter.Element` embedded in a reactive workflow.

  A node is the use of a reactive component or workflow inside a workflow.
  It is defined by its element and its initialization arguments.
  """
  alias Skitter.Element

  defstruct elem: nil, init: []

  @typedoc """
  A node is defined by the `t:Skitter.Element.t/0` and initialization arguments.
  """
  @type t :: %__MODULE__{
    elem: Element.t(),
    init: [any()]
  }
end
