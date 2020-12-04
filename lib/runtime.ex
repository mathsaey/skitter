# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime do
  @moduledoc false

  alias Skitter.{Component, Workflow}
  alias Skitter.Runtime.{DeploymentStore, Strategy}

  def deploy(wf = %Workflow{}) do
    ref = make_ref()

    data =
      wf.nodes
      |> Enum.map(fn {name, tup} -> {name, deploy(tup, ref)} end)
      |> Map.new()

    DeploymentStore.add(ref, data)
    ref
  end

  defp deploy({c = %Component{}, args}, ref) do
    Strategy.deploy(%{c | _rt: Map.put(c._rt, :deployment_ref, ref)}, args)
  end
end
