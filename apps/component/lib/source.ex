defmodule Skitter.Source do
  @moduledoc """
  Primitive Skitter Component which provides data from the external world.

  This components is directly implemented as a module so that it can bypass
  some of the checks of the Skitter component DSL. Specifically, it does not
  mention any input ports, although `in_ports_size` is set to 1.

  This allows this component to not list any ports, while still retaining
  correct runtime behaviour.
  """
  defstruct []

  def __skitter_metadata__ do
    %Skitter.Component.Metadata{
      name: "Source",
      description: "Connection between a workflow and the external world",
      effects: [],
      in_ports: [],
      out_ports: [:data],
      in_ports_size: 1
    }
  end

  def __skitter_react__(%Skitter.Component.Instance{component: __MODULE__}, [
        args
      ]) do
    {:ok, nil, [data: args]}
  end

  def __skitter_react_after_failure__(inst, args) do
    __skitter_react__(inst, args)
  end

  def __skitter_init__(_) do
    {:ok,
     %Skitter.Component.Instance{component: __MODULE__, state: %__MODULE__{}}}
  end

  def __skitter_terminate__(_), do: :ok
  def __skitter_create_checkpoint__(_), do: :nocheckpoint
  def __skitter_restore_checkpoint__(_), do: :nocheckpoint
  def __skitter_clean_checkpoint__(_, _), do: :nocheckpoint
end
