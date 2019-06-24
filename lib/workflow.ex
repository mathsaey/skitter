# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Workflow do
  @moduledoc """
  Data processing pipeline.

  A reactive workflow is a collection of connected reactive components and
  which make up a data processing pipeline. This module defines the internal
  representation of a skitter workflow as an elixir struct, along with the
  necessary utilities to operate on this struct. Finally, this module contains
  a macro which can be used to create reactive workflows.
  """
  alias Skitter.{Component, Port}

  defstruct name: nil, in_ports: [], out_ports: [], instances: %{}

  @typedoc """
  Internal workflow representation.

  A component is defined as a collection of `t:Skitter.Component.Instance.t/0`.
  Like a component, a workflow had a set of in -and out ports, and an optional
  name.

  NOTE: In future version of skitter, the map that contains the instances may be
  replaced by an array for more efficient indexing.
  """
  @type t :: %__MODULE__{
          name: String.t() | nil,
          in_ports: [Port.t(), ...],
          out_ports: [Port.t()],
          instances: %{optional(id()) => Component.Instance.t()}
        }

  @typedoc """
  Identifier of a component instance in a workflow.
  """
  @type id() :: atom()

  @typedoc """
  Destination of a link (i.e. an edge) in a workflow.

  A link can either point to a `t:Skitter.Port.t/0` of an instance, or to a port
  of the workflow itself. In the former case, an `t:address/0` is used; in the
  latter case, `nil` is used.
  """
  @type destination :: {id() | nil, Port.t()}
end
