# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Worker.Test.DummyMaster do
  use GenServer
  alias Skitter.Runtime

  def start(accept?) do
    GenServer.start(__MODULE__, accept?, name: Skitter.Master.Workers)
  end

  def init(accept?) do
    Runtime.publish(:skitter_master)
    {:ok, accept?}
  end

  def handle_call({:accept, _}, _, accept?) do
    {:reply, accept?, nil}
  end
end
