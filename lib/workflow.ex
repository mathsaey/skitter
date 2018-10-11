# Copyright 2018, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Workflow do
  @moduledoc """
  Tools to interact with skitter workflows.

  This module defines an API that can be used to fetch data from skitter
  workflow structures. Besides this, this module defines the `workflow/1` macro
  which can be used to define a skitter workflow.
  """

  @typedoc "Identifier of an instance or source in a workflow."
  @type workflow_identifier :: atom()

  @typedoc """
  Address a token can be sent to.

  Specified as the combination of a valid workflow identifier that refers to a
  component instance and the name of a valid port of that component.
  """
  @type destination :: {workflow_identifier(), Skitter.Component.port_name()}

  @typedoc """
  Outgoing links of a component

  Specified as a keyword list. Each key in the list corresponds to an out port
  of the component, while the values for this key correspond to all the
  `t:destination` ports this out port is connected with.
  """
  @type outgoing_links :: [{Skitter.Component.port_name(), [destination]}]

  # TODO: move once 3 "runtime" functions have been moved
  @typedoc "Data record with a destination."
  @type token :: {any(), destination()}

  @typedoc """
  Proto-instance type.

  A proto-instance is a tuple which contains the component it represents, its
  init argument (which can be anything), and a list of destinations, arranged
  by out port.
  """
  @type proto_instance :: {
          Skitter.Component.t(),
          any(),
          outgoing_links()
        }

  @typedoc """
  Workflow data structure.

  A workflow is defined as a combination of named sources and proto-instances.
  """
  @type t :: %__MODULE__{
          sources: %{required(workflow_identifier()) => [destination]},
          instances: %{required(workflow_identifier()) => proto_instance()}
        }

  @enforce_keys [:instances, :sources]
  defstruct [:instances, :sources]

  defp get_source!(workflow, key) do
    case Map.fetch(workflow.sources, key) do
      :error -> raise KeyError, "Key `#{inspect(key)}` not found in workflow"
      {:ok, any} -> any
    end
  end

  defp get_instance!(workflow, key) do
    case Map.fetch(workflow.instances, key) do
      :error -> raise KeyError, "Key `#{inspect(key)}` not found in workflow"
      {:ok, any} -> any
    end
  end

  defp get_instance!(workflow, key, idx) do
    elem(get_instance!(workflow, key), idx)
  end

  @doc """
  Retrieve the component of a proto-instance based on its identifier.

  ## Examples

      iex> get_component!(example_workflow(), :i1)
      Identity
      iex> get_component!(example_workflow(), :does_not_exist)
      ** (KeyError) Key `:does_not_exist` not found in workflow
  """
  @spec get_component!(t(), workflow_identifier()) ::
          Skitter.Component.t() | no_return
  def get_component!(workflow, key) do
    get_instance!(workflow, key, 0)
  end

  @doc """
  Retrieve the init argument of a proto-instance based on its identifier.

  ## Examples

      iex> get_init!(example_workflow(), :i1)
      nil
  """
  @spec get_init!(t(), workflow_identifier()) :: any() | no_return
  def get_init!(workflow, key) do
    get_instance!(workflow, key, 1)
  end

  @doc """
  Retrieve the links of a proto-instance based on its identifier.

  ## Examples

      iex> get_links!(example_workflow(), :i1)
      [value: [i3: :value]]
  """
  @spec get_links!(t(), workflow_identifier()) :: outgoing_links() | no_return
  def get_links!(workflow, key) do
    get_instance!(workflow, key, 2)
  end

  @doc """
  Initialize the proto_instance at `key`

  ## Examples

      iex> init_proto_instance(example_workflow(), :i1)
      {:ok, %Skitter.Component.Instance{component: WorkflowTest.Identity, state: []}}
  """
  @spec init_proto_instance(t(), workflow_identifier()) ::
          {:ok, Skitter.Component.instance()}
          | Skitter.Component.runtime_error()
          | no_return
  def init_proto_instance(workflow, key) do
    {comp, args, _} = get_instance!(workflow, key)
    Skitter.Component.init(comp, args)
  end

  # TODO: Move all of these to a runtime specific module later

  @doc """
  Create a list of tagged tokens based on the outputs of a component instance.

  Spits is the data that the component produced while reacting; they are
  represented as a keyword list where a key is an out port while the value is
  the data spit to that output port.

  Tokens are data records that will be sent to other components in the workflow.
  Each token is tagged with its destination.

  This function receives a list of spits, along with the list of outgoing links
  of a component instance. Based on these, it creates a list of tagged tokens.

  ## Examples

      iex> links = get_links!(example_workflow(), :i1)
      [value: [i3: :value]]
      iex> spits_to_tokens(links, [value: 20])
      [{20, {:i3, :value}}]
  """
  @spec spits_to_tokens(outgoing_links(), [
          {Skitter.Component.port_name(), any()}
        ]) :: [token()]
  def spits_to_tokens(links, spits) do
    Enum.flat_map(spits, fn {port, val} ->
      Enum.map(Keyword.get(links, port, []), fn dest -> {val, dest} end)
    end)
  end

  @doc """
  Generate tokens from spits like `spits_to_tokens/2`, but fetch the links.

  Identical to `spits_to_tokens/2`, but fetches the links from a workflow first.

  ## Examples

      iex> spits_to_tokens!(example_workflow(), :i1, [value: 20])
      [{20, {:i3, :value}}]
  """
  @spec spits_to_tokens!(t(), workflow_identifier(), [
          {Skitter.Component.port_name(), any()}
        ]) :: [token()]
  def spits_to_tokens!(workflow, key, spits) do
    links = get_links!(workflow, key)
    spits_to_tokens(links, spits)
  end

  @doc """
  Generate tokens out of the initial data for a workflow.

  The initial data is provided as a keyword list, where the keys are source
  names and the values are values to be sent to the sources. There should be a
  value for each source; this is currently not verified.

  ## Examples

      iex> source_data_to_tokens!(example_workflow(), [s1: 20, s2: 22])
      [{20, {:i1, :value}}, {22, {:i2, :value}}]
      iex> source_data_to_tokens!(example_workflow(), [does_not_exist: 20])
      ** (KeyError) Key `:does_not_exist` not found in workflow
  """
  @spec source_data_to_tokens!(t(), [{workflow_identifier(), any()}]) :: [
          token()
        ]
  def source_data_to_tokens!(workflow, source_data) do
    Enum.flat_map(source_data, fn
      {source, val} ->
        Enum.map(get_source!(workflow, source), fn dest -> {val, dest} end)
    end)
  end

  # ------ #
  # Macros #
  # ------ #

  @doc """
  Create a workflow.

  This macro is a shorthand for the `Skitter.Workflow.DSL.workflow/1` macro,
  which enables the creation of skitter workflows. Please refer to the
  documentation of the `Skitter.Workflow.DSL`.
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
