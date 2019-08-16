# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Element do
  @moduledoc """
  Type definition and utilities for data processing elements.

  Any `Skitter.Workflow` consists of data processing elements: entities which
  are responsible for processing data. These entities are a `Skitter.Component`
  or `Skitter.Workflow`.

  This module defines the element type (`t:t/0`) type and related operations.
  """
  alias Skitter.{Component, Workflow, Handler, Port}

  @typedoc """
  Data processing element type.

  An element is a `t:Skitter.Component.t/0` or `t:Skitter.Workflow.t/0`.
  For documentation purposes, we define the element as a map that is general
  enough to be a `t:Skitter.Component.t/0` or `t:Skitter.Workflow.t/0`.
  """
  @type t :: %{
          name: String.t() | nil,
          handler: Handler.t(),
          in_ports: [Port.t(), ...],
          out_ports: [Port.t()]
        }

  @doc """
  Test if the module of a struct is a valid element.

  Due to limitation in elixir, the value of the `__struct__` key needs to be
  passed to the guard.
  """
  defguard is_element(module) when module in [Component, Workflow]
end
