# Copyright 2018 - 2022, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.DSL.WorkflowTest do
  use ExUnit.Case, async: true

  import Skitter.DSL.Workflow
  import Skitter.DSL.Operation, only: [defoperation: 3]

  defoperation Example, in: in_port, out: out_port, strategy: DefaultStrategy do
  end

  defoperation Join, in: [left, right], out: _ do
  end

  doctest Skitter.DSL.Workflow
end
