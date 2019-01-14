# Copyright 2018, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime do
  @moduledoc """
  Interface to Skitter's runtime system.
  """

  def add_node(_node) do
    # TODO
  end

  def load_workflow(workflow) do
    case Skitter.Runtime.Nodes.all() do
      [] -> {:error, :no_workers}
      _ -> Skitter.Runtime.Workflow.load(workflow)
    end
  end

  defdelegate react(wf, args), to: Skitter.Runtime.Workflow
end
