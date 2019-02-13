# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Instance.Manager.Server do
  @moduledoc false

  use GenServer
  alias Skitter.Runtime.Workflow

  defstruct [:workflow]

  def start_link(workflow) do
    GenServer.start_link(__MODULE__, workflow)
  end

  def init(workflow) do
    {:ok, ref} = Workflow.load(workflow)
    {:ok, %__MODULE__{workflow: ref}}
  end

  def handle_cast({:react, src_data}, s = %__MODULE__{workflow: ref}) do
    Workflow.react(ref, src_data)
    {:noreply, s}
  end
end

