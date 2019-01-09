# Copyright 2018, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Nodes.LoadBalancer do
  @moduledoc false

  alias __MODULE__.Server

  def select_permanent() do
    GenServer.call(Server, :permanent)
  end

  def select_transient() do
    GenServer.call(Server, :transient)
  end
end
