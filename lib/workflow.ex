# Copyright 2018, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Workflow do
  @moduledoc """
  Tools to interact with skitter workflows.

  This module defines an API that can be used to fetch data from skitter
  workflows . Besides this, this module defines the `workflow/2` macro
  which can be used to define a skitter workflow.
  """

  alias Skitter.Workflow.Metadata

  # ----- #
  # Types #
  # ----- #

  @typedoc "Identifier of a component instance in a workflow."
  @type instance_identifier :: atom()

  @typedoc "Identifier of a source in a workflow."
  @type source_address :: Skitter.Component.port_name()

  @typedoc """
  Address a token can be sent to.

  Specified as the combination of a valid workflow identifier that refers to a
  component instance and the name of a valid port of that component.
  """
  @type port_address :: {instance_identifier(), Skitter.Component.port_name()}

  @typedoc """
  Address a token can originate from.

  Can be either an out port or a source.
  """
  @type address :: port_address() | source_address()

  @typedoc """
  Instance type.

  An instance type is a tuple of a `Skitter.Component.t()`, and an argument to
  initialize this component. The initialization argument can be any valid elixir
  value.
  """
  @type instance :: {Skitter.Component.t(), any()}

  @typedoc """
  Workflow type.

  A workflow is represented by an elixir module which stores its definition.
  This module should satisfy the `Skitter.Workflow.Behaviour` behaviour.
  """
  @type t :: module()

  # --------- #
  # Interface #
  # --------- #

  @doc """
  Verify if something is a workflow

  ## Examples

      iex> is_workflow?(5)
      false
      iex> is_workflow?(Enum)
      false
      iex> is_workflow?(ExampleWorkflow)
      true
  """
  @spec is_workflow?(any()) :: boolean()
  def is_workflow?(any)

  def is_workflow?(mod) when is_atom(mod) do
    function_exported?(mod, :__skitter_metadata__, 0) and
      match?(%Metadata{}, mod.__skitter_metadata__)
  end

  def is_workflow?(_), do: false

  @spec name(t()) :: String.t()
  def name(wf), do: wf.__skitter_metadata__.name

  @doc """
  Get the description of a workflow

  An empty string is returned if no documentation is present.

  ## Examples

      iex> description(ExampleWorkflow)
      ""
  """
  @spec description(t()) :: String.t()
  def description(wf), do: wf.__skitter_metadata__.description

  @doc """
  Get the in ports of a workflow.

  ## Examples

      iex> in_ports(ExampleWorkflow)
      [:value]
  """
  @spec in_ports(t()) :: [Skitter.Component.port_name(), ...]
  def in_ports(wf), do: wf.__skitter_metadata__.in_ports

  @doc """
  Check if a keyword lists matches with the in ports of a workflow.

  This means that the keys of the keyword list and source names should be
  identical. Ordering is not taken into account.

  ## Examples

      iex> in_ports_match?(ExampleWorkflow, s1: 3, s2: 4)
      true
      iex> in_ports_match?(ExampleWorkflow, s1: 3, s1: 4)
      false
      iex> in_ports_match?(ExampleWorkflow, s1: 3)
      false
  """
  def in_ports_match?(workflow, kw_list) do
    kw_keys =
      Enum.reduce_while(kw_list, MapSet.new(), fn
        {key, _}, set ->
          if MapSet.member?(set, key) do
            {:halt, false}
          else
            {:cont, MapSet.put(set, key)}
          end
      end)

    kw_keys && MapSet.equal?(kw_keys, MapSet.new(in_ports(workflow)))
  end

  @doc """
  Obtain the destinations of an address based on its name.

  ## Examples

      iex> get_source!(ExampleWorkflow, :s1)
      [i1: :value]
      iex> get_source!(ExampleWorkflow, :foo)
      ** (KeyError) Key `:foo` not found in workflow
  """

  @spec get_destination!(t(), address()) :: [port_address()] | no_return
  def get_destination!(workflow, key) do
    case Map.fetch(workflow.__skitter_links__(), key) do
      :error -> raise KeyError, "Key `#{inspect(key)}` not found in workflow"
      {:ok, any} -> any
    end
  end

  @doc """
  List the instances of a component.

  ## Examples

      iex> get_links(ExampleWorkflow)
      [
        i1: {Identity, nil, [value: [i3: :value]]},
        i2: {Identity, nil, []},
        i3: {Identity, nil, []}
      ]
  """
  @spec get_links(t()) :: %{required(address()) => port_address()}
  def get_links(workflow), do: workflow.__skitter_links__

  @doc """
  Fetch an instance from a workflow based on its identifier.

  ## Examples

      iex> get_instance!(ExampleWorkflow, :i1)
      {Identity, nil}
      iex> get_instance!(ExampleWorkflow, :does_not_exist)
      ** (KeyError) Key `:does_not_exist` not found in workflow
  """
  @spec get_instance!(t(), instance_identifier()) :: instance() | no_return
  def get_instance!(workflow, key) do
    case Map.fetch(workflow.__skitter_instances__, key) do
      :error -> raise KeyError, "Key `#{inspect(key)}` not found in workflow"
      {:ok, any} -> any
    end
  end

  @doc """
  List the instances of a component.

  ## Examples

      iex> get_instances(ExampleWorkflow))
      [
        i1: {Identity, nil, [value: [i3: :value]]},
        i2: {Identity, nil, []},
        i3: {Identity, nil, []}
      ]
  """
  @spec get_instances(t()) :: %{required(instance_identifier()) => instance()}
  def get_instances(workflow), do: workflow.__skitter_instances__

  # ------ #
  # Macros #
  # ------ #

  @doc """
  Create a workflow.

  This macro is a shorthand for the `Skitter.Workflow.DSL.workflow/3` macro,
  which enables the creation of skitter workflows. Please refer to the
  documentation of the `Skitter.Workflow.DSL`.
  """
  defmacro workflow(name, ports, do: body) do
    quote do
      require Skitter.Workflow.DSL

      Skitter.Workflow.DSL.workflow unquote(name), unquote(ports) do
        unquote(body)
      end
    end
  end
end
