# Copyright 2018, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Workflow.Matcher do
  @moduledoc false

  def new, do: Map.new()

  def empty?(map) when map == %{}, do: true
  def empty?(_), do: false

  def add(matcher, token = {id, _, _}, instances) do
    {entry, arity} = get_and_update_entry(matcher, token, instances)

    if map_size(entry) == arity do
      {:ready, Map.delete(matcher, id), id, entry_to_args(instances, id, entry)}
    else
      {:ok, Map.put(matcher, id, {entry, arity})}
    end
  end

  defp get_and_update_entry(matcher, {id, port, data}, instances) do
    case Map.get(matcher, id) do
      nil -> {%{port => data}, instances[id].arity}
      {entry, arity} -> {Map.put(entry, port, data), arity}
    end
  end

  defp entry_to_args(instances, id, entry) do
    instances[id].in_ports
    |> Enum.map(fn port -> entry[port] end)
  end
end
