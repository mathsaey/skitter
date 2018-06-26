defmodule Skitter.Component.Metadata do
  @moduledoc false
  @data [:name, :description, :effects, :in_ports, :out_ports]

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
