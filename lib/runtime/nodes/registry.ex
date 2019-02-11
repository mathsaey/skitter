# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Nodes.Registry do
  @moduledoc false
  alias __MODULE__.Server

  def all() do
    MapSet.to_list(GenServer.call(Server, :all))
  end

  def connect([]), do: true

  def connect(nodes) when is_list(nodes) do
    lst =
      nodes
      |> Enum.map(&connect/1)
      |> Enum.reject(&(&1 == true))
    lst == [] || lst
  end

  def connect(node) do
    GenServer.call(Server, {:connect, node})
  end
end
