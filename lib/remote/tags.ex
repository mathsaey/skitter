# Copyright 2018 - 2022, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Remote.Tags do
  @moduledoc false
  # This module maintains a table with the tags of remote workers. The handlers of a mode are
  # responsible for keeping this table up to date.

  alias Skitter.{Config, Remote}

  def start_link do
    :ets.new(__MODULE__, [:bag, :named_table, {:read_concurrency, true}])
    :ok
  end

  # Handler Functions
  # -----------------

  def local, do: Config.get(:tags, [])
  def remote(node), do: Remote.on(node, __MODULE__, :local, [])

  def add(node, tags \\ []), do: Enum.each(tags, &:ets.insert(__MODULE__, {&1, node}))
  def remove(node), do: :ets.match_delete(__MODULE__, {:"$_", node})
  def remove_all(), do: :ets.delete_all_objects(__MODULE__)

  # Remote Functions
  # ----------------

  def of_worker(node), do: :ets.match(__MODULE__, {:"$1", node}) |> Enum.map(&hd/1)
  def workers_with(tag), do: :ets.match(__MODULE__, {tag, :"$1"}) |> Enum.map(&hd/1)
  def of_all_workers, do: Enum.map(Remote.workers(), fn node -> {node, of_worker(node)} end)
end
