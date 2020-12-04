# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Location do
  @moduledoc false

  def resolve(available, []), do: available
  def resolve(_, on: node), do: node
  def resolve(_, with: pid), do: :erlang.node(pid)

  def resolve(available, avoid: pid) do
    node = :erlang.node(pid)
    List.delete(available, node)
  end
end
