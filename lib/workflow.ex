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

  # Sources
  # -------

  @doc """
  Obtain the destinations of a source based on its name.

  ## Examples

      iex> get_source!(example_workflow(), :s1)
      [i1: :value]
      iex> get_source!(example_workflow(), :foo)
      ** (KeyError) Key `:foo` not found in workflow
  """
  @spec get_source!(t(), workflow_identifier()) :: [destination()] | no_return
  def get_source!(workflow, key) do
    case Map.fetch(workflow.sources, key) do
      :error -> raise KeyError, "Key `#{inspect(key)}` not found in workflow"
      {:ok, any} -> any
    end
  end

  @doc """
  List the sources of a component.

  ## Examples

      iex> get_sources(example_workflow())
      [:s1, :s2]

  """
  @spec get_sources(t()) :: [workflow_identifier()]
  def get_sources(workflow), do: Map.keys(workflow.sources)

  @doc """
  Check if a keyword lists matches with the sources of a workflow.

  This means that the keys of the keyword list and source names should be
  identical. Ordering is not taken into account.

  ## Examples

      iex> sources_match?(example_workflow(), s1: 3, s2: 4)
      true
      iex> sources_match?(example_workflow(), s1: 3, s1: 4)
      false
      iex> sources_match?(example_workflow(), s1: 3)
      false
  """
  def sources_match?(workflow, kw_list) do
    kw_keys =
      Enum.reduce_while(kw_list, MapSet.new(), fn
        {key, _}, set ->
          if MapSet.member?(set, key) do
            {:halt, false}
          else
            {:cont, MapSet.put(set, key)}
          end
      end)

    kw_keys && MapSet.equal?(kw_keys, MapSet.new(Map.keys(workflow.sources)))
  end

  # Instances
  # ---------

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

      iex> init_proto_instance!(example_workflow(), :i1)
      {:ok, %Skitter.Component.Instance{component: WorkflowTest.Identity, state: []}}
  """
  @spec init_proto_instance!(t(), workflow_identifier()) ::
          {:ok, Skitter.Component.instance()}
          | Skitter.Component.runtime_error()
          | no_return
  def init_proto_instance!(workflow, key) do
    {comp, args, _} = get_instance!(workflow, key)
    Skitter.Component.init(comp, args)
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
