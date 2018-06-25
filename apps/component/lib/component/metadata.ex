defmodule Skitter.Component.Metadata do
  @moduledoc """
  Skitter metadata struct.

  This struct defines the collection of skitter metadata that a component
  should provide.
  """
  @data [:name, :description, :effects, :in_ports, :out_ports]

  @typedoc """
  Skitter metadata type.

  This type defines a struct which should contain all the keys specified in
  this type.
  """
  @type t :: %__MODULE__{
          name: String.t(),
          description: String.t(),
          effects: [keyword()],
          in_ports: [atom()],
          out_ports: [atom()]
        }

  @enforce_keys @data
  defstruct @data
end
