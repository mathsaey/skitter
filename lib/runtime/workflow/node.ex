# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Workflow.Node do
  @moduledoc false

  # Runtime representation of a node in the workflow (i.e. a component instance)
  # + metadata + it's environment.
  defstruct [:ref, :links, :meta]
end
