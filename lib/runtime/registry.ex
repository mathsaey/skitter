# Copyright 2018 - 2021, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Registry do
  @moduledoc false
  alias Skitter.Remote

  @node_tab __MODULE__.Nodes
  @tag_tab __MODULE__.Tags

  def start_link do
    with @node_tab <- :ets.new(@node_tab, [:named_table, {:read_concurrency, true}]),
         @tag_tab <- :ets.new(@tag_tab, [:bag, :named_table, {:read_concurrency, true}]) do
      :ok
    end
  end

  def add(node, tags \\ []) do
    :ets.insert_new(@node_tab, {node})
    Enum.each(tags, &:ets.insert(@tag_tab, {&1, node}))
  end

  def remove(node) do
    :ets.delete(@node_tab, node)
    :ets.match_delete(@tag_tab, {:"$_", node})
  end

  def remove_all() do
    :ets.delete_all_objects(@node_tab)
    :ets.delete_all_objects(@tag_tab)
  end

  def all, do: :ets.tab2list(@node_tab) |> Enum.map(&elem(&1, 0))
  def with_tag(tag), do: :ets.match(@tag_tab, {tag, :"$1"}) |> Enum.map(&hd/1)
  def tags(node), do: :ets.match(@tag_tab, {:"$1", node}) |> Enum.map(&hd/1)
  def connected?(node), do: :ets.member(@node_tab, node)
  def all_with_tags, do: Enum.map(all(), fn node -> {node, tags(node)} end)

  def on_all(mod, func, args), do: Remote.on_many(all(), mod, func, args)
  def on_all(fun), do: Remote.on_many(all(), fun)

  def on_tagged(tag, mod, func, args), do: tag |> with_tag() |> Remote.on_many(mod, func, args)
  def on_tagged(tag, fun), do: tag |> with_tag() |> Remote.on_many(fun)
end
