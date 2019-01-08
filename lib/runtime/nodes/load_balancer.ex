# Copyright 2018, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Nodes.LoadBalancer do
  @moduledoc false

  alias Skitter.Runtime.Nodes

  # TODO: something less naive here, at the very least cache the registered
  # nodes and use round robin.

  def select_permanent() do
    Enum.random(Nodes.Registry.all())
  end

  def select_transient() do
    Enum.random(Nodes.Registry.all())
  end
end
