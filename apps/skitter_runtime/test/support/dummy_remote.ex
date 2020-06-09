# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Test.DummyRemote do
  use GenServer
  alias Skitter.Runtime

  def start(name, mode, accept?), do: GenServer.start(__MODULE__, {mode, accept?}, name: name)

  def init({mode, accept?}) do
    Runtime.publish(mode)
    {:ok, accept?}
  end

  def handle_call({:accept, _}, _, accept?) do
    {:reply, accept?, nil}
  end
end
