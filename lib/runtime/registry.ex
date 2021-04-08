# Copyright 2018 - 2021, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Registry do
  @moduledoc false
  alias Skitter.Remote

  def start_link do
    case :ets.new(__MODULE__, [:set, :protected, :named_table, {:read_concurrency, true}]) do
      __MODULE__ -> :ok
    end
  end

  def add(node), do: :ets.insert_new(__MODULE__, {node, nil})
  def remove(node), do: :ets.delete(__MODULE__, node)
  def remove_all(), do: :ets.delete_all_objects(__MODULE__)

  def all, do: :ets.tab2list(__MODULE__) |> Enum.map(&elem(&1, 0))
  def connected?(node), do: :ets.member(__MODULE__, node)

  def on_all(mod, func, args), do: Remote.on_many(all(), mod, func, args)
  def on_all(fun), do: Remote.on_many(all(), fun)
end
