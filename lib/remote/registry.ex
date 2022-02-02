# Copyright 2018 - 2022, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Remote.Registry do
  @moduledoc false
  # This module maintains a table with remote runtimes. The handlers of a mode are responsible for
  # keeping this table up to date.

  def start_link do
    :ets.new(__MODULE__, [:bag, :named_table, {:read_concurrency, true}])
    :ok
  end

  # Handler Functions
  # -----------------

  def add(node, mode), do: :ets.insert(__MODULE__, {node, mode})
  def remove(node), do: :ets.delete(__MODULE__, node)
  def remove_all(), do: :ets.delete_all_objects(__MODULE__)

  # Remote Functions
  # ----------------

  def all, do: :ets.tab2list(__MODULE__)
  def master, do: :ets.match(__MODULE__, {:"$1", :master}) |> hd() |> hd()
  def workers, do: :ets.match(__MODULE__, {:"$1", :worker}) |> Enum.map(&hd/1)
  def connected?(node), do: :ets.member(__MODULE__, node)
end
