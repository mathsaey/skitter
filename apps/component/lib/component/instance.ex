defmodule Skitter.Component.Instance do
  @moduledoc """
  Skitter instance struct.

  This struct is used to store all of the data stored by a component instance.
  """
  @data [:state, :component]

  @typedoc """
  Skitter instance type.

  This type defines a struct which contains all the data stored by a component
  instance.
  """
  @type t :: %__MODULE__{
          state: struct(),
          component: module()
        }

  @enforce_keys @data
  defstruct @data

  @doc """
  Verify if something is a component instance

  ## Examples

      iex> Instance.is_instance?(:foo)
      false
      iex> Instance.is_instance?(Instance.create(nil, nil))
      true
  """
  def is_instance?(%__MODULE__{}), do: true
  def is_instance?(_), do: false

  @doc """
  Create a new component instance

  ## Examples

      iex> Instance.create(MyComponent, :some_state_struct_here)
      %Instance{state: :some_state_struct_here, component: MyComponent}
  """
  def create(comp, state), do: %__MODULE__{state: state, component: comp}

  @doc "Retrieve the state of a component instance"
  def state(%__MODULE__{state: state}), do: state

  @doc "Retrieve the component of an instance"
  def component(%__MODULE__{component: component}), do: component
end
