# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Workflow do
  @moduledoc false

  alias __MODULE__
  defstruct [:key]

  # TODO: Make it possible to unload a workflow
  #
  def load(workflow) do
    {:ok, key} = Workflow.Loader.load(workflow)
    {:ok, %__MODULE__{key: key}}
  end

  def react(%__MODULE__{key: ref}, args) do
    Workflow.Replica.react(ref, args)
  end
end

defimpl Inspect, for: Skitter.Runtime.Workflow do
  import Inspect.Algebra

  def inspect(inst, opts) do
    container_doc(
      "#RuntimeWorkflow[",
      [inst.key],
      "]",
      opts,
      fn el, opts -> to_doc(el, opts) end
    )
  end
end
