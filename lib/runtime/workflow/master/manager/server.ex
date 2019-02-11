# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Workflow.Master.Manager.Server do
  @moduledoc false

  use GenServer, restart: :transient
  alias Skitter.Runtime.Workflow

  def start_link(workflow) do
    GenServer.start_link(__MODULE__, workflow)
  end

  def init(workflow) do
    {:ok, _ref} = Workflow.Loader.load(workflow)
  end

  def handle_cast({:react, src_data}, ref) do
    Workflow.Replica.react(ref, src_data)
    {:noreply, ref}
  end
end

