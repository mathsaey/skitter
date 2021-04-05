# Copyright 2018 - 2021, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Workflow do
  @moduledoc """
  Workflow type definition and utilities.

  A reactive workflow defines a data processing pipeline. It is defined as a set of components
  connected through various links. A workflow stores these components and links, along with some
  additional information about the workflow.

  In order to enable the reuse of workflows, workflows may define in -and out ports. When this is
  done, these workflows may be embedded inside another workflow. Note that a runtime is always
  flattened using `flatten/1` before it is deployed.

  This module defines the workflow type along with some utilities to work with this type. It is
  not recommended to define a workflow manually. Instead, the use of `Skitter.DSL.workflow/2` is
  preferred.
  """
  alias Skitter.{Component, Port}

  @typedoc """
  Internal workflow representation.

  A workflow is stored as a map, where each name refers to a single node, which is either a
  `t:component/0` or `t:workflow/0`. Besides this, the in -and out ports of the workflow are
  stored. The outgoing links of the in ports of a workflow are stored along with the in ports.
  """
  @type t :: %__MODULE__{
          in: links(),
          out: [Port.t()],
          nodes: %{name() => component() | workflow()}
        }

  defstruct in: [], out: [], nodes: %{}

  @typedoc """
  Component embedded inside a workflow.

  A component in a workflow is stored along with its initialization arguments (which are passed to
  `c:Skitter.Strategy.deploy/2`) and the outgoing links of each of its out ports.
  """
  @type component :: %__MODULE__.Component{
          component: Component.t(),
          args: any(),
          links: links()
        }

  @typedoc """
  Workflow embedded inside a workflow.

  A workflow nested inside a workflow is stored along with the outgoing links of its out ports.
  """
  @type workflow :: %__MODULE__.Workflow{
          workflow: t(),
          links: links()
        }

  @typedoc """
  Collection of outgoing links.

  Links are stored as a keyword list. Each key in this list represents an out port, while the
  value of this key is a list which references the destinations of this out port.
  """
  @type links :: [{Port.t(), [destination()]}]

  @typedoc """
  Link destination.

  This type stores the destination of a link. A link can point to a component or to an out port of
  the workflow. In the first case, the name of the component and the name of the out port are
  stored, in the second, only the name of the out port is stored.
  """
  @type destination :: {name(), Port.t()} | Port.t()

  @typedoc """
  Instance name

  A name is used to refer to a component embedded inside a workflow.
  """
  @type name :: atom()

  defmodule Component do
    @moduledoc false
    defstruct [:component, :args, links: []]
  end

  defmodule Workflow do
    @moduledoc false
    defstruct [:workflow, links: []]
  end
end
