# Copyright 2018, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Matcher do
  @moduledoc false

  alias Skitter.Workflow
  alias Skitter.Component

  @type t :: %{
          optional(Workflow.workflow_identifier()) =>
            {%{required(Component.port_name()) => any()}, pos_integer()}
        }

  @spec new :: t()
  def new, do: Map.new()

  @spec add(
          t(),
          {Workflow.workflow_identifier(), Component.port_name()},
          any(),
          Workflow.t()
        ) ::
          {:ok, t()}
          | {:ready, t(), Workflow.workflow_identifier(), [any(), ...]}

  def add(matcher, {id, port}, data, workflow) do
    {entry, arity} =
      case Map.get(matcher, id) do
        nil ->
          arity = Component.arity(Workflow.get_component!(workflow, id))
          {%{port => data}, arity}

        {entry, arity} ->
          {Map.put(entry, port, data), arity}
      end

    if map_size(entry) == arity do
      {:ready, Map.delete(matcher, id), id, entry_to_args(workflow, id, entry)}
    else
      {:ok, Map.put(matcher, id, {entry, arity})}
    end
  end

  defp entry_to_args(workflow, id, entry) do
    ports = Component.in_ports(Workflow.get_component!(workflow, id))
    Enum.map(ports, fn port -> entry[port] end)
  end
end
