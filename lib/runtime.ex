# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime do
  @moduledoc false

  alias Skitter.{Context, Workflow}
  alias Skitter.Runtime.{DeploymentStore, Strategy}

  def deploy(wf = %Workflow{}, wf_ref) do
    ref = make_ref()

    data =
      wf.nodes
      |> Enum.map(fn {name, {comp, args}} ->
        {
          name,
          Strategy.deploy(
            comp,
            %Context{deployment_ref: ref, workflow_ref: wf_ref, workflow_id: name},
            args
          )
        }
      end)
      |> Map.new()

    DeploymentStore.add(ref, data)
    ref
  end
end
