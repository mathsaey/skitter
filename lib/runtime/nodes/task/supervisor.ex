# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Nodes.Task.Supervisor do
  @moduledoc false

  def child_spec([]) do
    Supervisor.child_spec({Task.Supervisor, name: __MODULE__}, [])
  end
end
