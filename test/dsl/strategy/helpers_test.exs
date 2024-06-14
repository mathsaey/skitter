# Copyright 2018 - 2024, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.DSL.Strategy.HelpersTest do
  use ExUnit.Case, async: true

  use Skitter
  alias Skitter.Strategy.Context
  alias Skitter.Operation.Callback.Result

  doctest Skitter.DSL.Strategy.Helpers
end
