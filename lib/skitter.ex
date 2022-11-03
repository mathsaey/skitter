# Copyright 2018 - 2022, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter do
  @moduledoc """
  Skitter entry point.

  This module serves a single point which can be used to access the features a  typical user is
  expected to use. Concretly, this module offers access to both the Skitter runtime system and to
  the DSLs defined by Skitter. The runtime system can be accessed through `deploy/1` and `stop/1`,
  which are shorthands for `Skitter.Runtime.deploy/1` and `Skitter.Runtime.stop/1`, respectively.
  The DSLs can be access by adding `use Skitter` to the top of a file or module, which serves as a
  shorthand for adding `use Skitter.DSL`.

  For additional information, please refer to the documentation of `Skitter.Runtime` and
  `Skitter.DSL`.
  """

  defmacro __using__(_opts) do
    quote do
      use Skitter.DSL
    end
  end

  defdelegate deploy(workflow), to: Skitter.Runtime
  defdelegate stop(ref), to: Skitter.Runtime
end
