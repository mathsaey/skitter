# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Workflow do
  @moduledoc false

  alias __MODULE__

  # TODO: Make it possible to unload a workflow

  defdelegate load(workflow), to: Workflow.Loader
  defdelegate react(ref, args), to: Workflow.Replica
end
