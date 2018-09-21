# Copyright 2018, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Workflow do
  @moduledoc """
  Documentation for Workflow.
  """

  @enforce_keys [:map]
  defstruct [:map]

  @behaviour Access
  def fetch(%Workflow{map: m}, key), do: Map.fetch(m, key)

  def get_and_update(%Workflow{map: _m}, _key, _function) do
    raise ArgumentError, "Modifying a workflow is not supported"
  end

  def pop(%Workflow{map: _m}, _key) do
    raise ArgumentError, "Modifying a workflow is not supported"
  end

  @doc """
  Hello world.

  ## Examples

      iex> Workflow.hello
      :world

  """
  def hello do
    :world
  end
end
