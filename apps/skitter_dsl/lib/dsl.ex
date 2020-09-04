# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.DSL do
  @moduledoc """
  Domain specific language support for Skitter.

  `use Skitter.DSL` can be used to automatically load all the domain-specific
  languages defined by this application:

  - `Skitter.DSL.Component.defcomponent/3`
  - `Skitter.DSL.Workflow.defworkflow/3`
  - `Skitter.DSL.Strategy.defstrategy/2`
  """

  @doc false
  defmacro __using__(_opts) do
    quote do
      import Skitter.DSL.Component
      import Skitter.DSL.Workflow
      import Skitter.DSL.Strategy
      :ok
    end
  end
end
