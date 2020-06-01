# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Element do
  @moduledoc """
  Type definition of a data processing element.

  Any `Skitter.Workflow` consists of data processing elements: entities which
  are responsible for processing data. These entities are a `Skitter.Component`
  or `Skitter.Workflow`.

  The only purpose of this module is to formalise the notion of a data
  processing element and to define its type, `t:t/0`.
  """
  alias Skitter.{Component, Workflow}

  @typedoc """
  Data processing element, a `t:Component.t/0` or `t:Workflow.t/0`
  """
  @type t :: Component.t() | Workflow.t()
end
