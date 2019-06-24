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
  alias Skitter.{Component, Workflow, Port}

  defstruct component: nil, instantiation: [], links: %{}

  @typedoc """
  A component instance stores its component, instantiation parameters and its
  connections to the workflow.
  """
  @type t :: %__MODULE__{
    component: Component.t(),
    instantiation: [any()],
    links: %{optional(Port.t()) => [Workflow.destination()]}
  }
end
