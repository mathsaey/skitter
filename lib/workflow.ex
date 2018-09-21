# Copyright 2018, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Workflow do
  @moduledoc """
  Documentation for Workflow.
  """

  @enforce_keys [:map]
  defstruct [:map]

  @behaviour Access
  def fetch(%__MODULE__{map: m}, key), do: Map.fetch(m, key)

  def get_and_update(%__MODULE__{map: _m}, _key, _function) do
    raise ArgumentError, "Modifying a workflow is not supported"
  end

  def pop(%__MODULE__{map: _m}, _key) do
    raise ArgumentError, "Modifying a workflow is not supported"
  end

  defp get_item(workflow, key, idx) do
    case workflow[key] do
      nil -> raise KeyError, "Key `#{inspect(key)}` not found in workflow"
      tup -> elem(tup, idx)
    end
  end

  def get_component(workflow, key) do
    get_item(workflow, key, 0)
  end

  def get_init(workflow, key) do
    get_item(workflow, key, 1)
  end

  def get_link(workflow, key) do
    get_item(workflow, key, 2)
  end

  # ------ #
  # Macros #
  # ------ #

  @doc """
  Create a workflow.
  """
  defmacro workflow(do: body) do
    quote do
      require Skitter.Workflow.DSL

      Skitter.Workflow.DSL.workflow do
        unquote(body)
      end
    end
  end
end
