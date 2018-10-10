# Copyright 2018, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Workflow do
  @moduledoc """
  Documentation for Workflow.
  """

  @enforce_keys [:instances, :sources]
  defstruct [:instances, :sources]

  defp get_instance!(workflow, key) do
    case Map.fetch(workflow.instances, key) do
      :error -> raise KeyError, "Key `#{inspect(key)}` not found in workflow"
      {:ok, any} -> any
    end
  end

  defp get_instance!(workflow, key, idx) do
    elem(get_instance!(workflow, key), idx)
  end

  # TODO: init met idx

  @doc """

  ## Examples

    iex> get_component(example_workflow(), :i)
    Identity
    iex> get_component(example_workflow(), :does_not_exist)
    ** (KeyError) Key `:does_not_exist` not found in workflow
  """
  def get_component(workflow, key) do
    get_instance!(workflow, key, 0)
  end

  @doc """

  ## Examples

    iex> get_init(example_workflow(), :i)
    nil
  """
  def get_init(workflow, key) do
    get_instance!(workflow, key, 1)
  end

  @doc """

  ## Examples

    iex> get_links(example_workflow(), :i)
    []
  """
  def get_links(workflow, key) do
    get_instance!(workflow, key, 2)
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
