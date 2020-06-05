# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Worker.Test.DummyMaster do
  use GenServer
  alias Skitter.Runtime

  def start() do
    GenServer.start(__MODULE__, [], name: Skitter.Master.WorkerConnection)
  end

  def init(_) do
    Runtime.publish(:skitter_master)
    {:ok, nil}
  end

  def handle_call({:connect, _}, _, nil) do
    {:reply, :ok, nil}
  end
end
