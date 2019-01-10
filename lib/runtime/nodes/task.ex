# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Nodes.Task do
  @moduledoc false
  @supname __MODULE__.Supervisor

  alias Skitter.Runtime.Nodes.Registry

  def supervisor(), do: {Task.Supervisor, name: @supname}

  def on(node, mod, func, args), do: hd(on_many([node], mod, func, args))
  def on_all(mod, func, args), do: on_many(Registry.all(), mod, func, args)

  defp on_many(nodes, mod, func, args) do
    nodes
    |> Enum.map(&Task.Supervisor.async({@supname, &1}, mod, func, args))
    |> Enum.map(&Task.await(&1))
  end
end
