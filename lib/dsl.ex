# Copyright 2018 - 2022, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.DSL do
  @moduledoc """
  Domain-specific language support for Skitter.

  This module enables the various DSLs offered by Skitter.
  `use Skitter.DSL` imports:

  - `Skitter.DSL.Component.defcomponent/3`
  - `Skitter.DSL.Strategy.defstrategy/3`
  - `Skitter.DSL.Workflow.workflow/2`
  - This module
  """

  defmacro __using__(_opts) do
    quote do
      import Skitter.DSL.Component, only: [defcomponent: 3, defcomponent: 2]
      import Skitter.DSL.Workflow, only: [workflow: 1, workflow: 2]
      import Skitter.DSL.Strategy, only: [defstrategy: 2, defstrategy: 3]
      import unquote(__MODULE__)
    end
  end
end
