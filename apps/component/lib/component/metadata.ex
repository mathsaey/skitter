defmodule Skitter.Component.Metadata do
  @moduledoc false
  @data [:name, :description, :effects, :in_ports, :out_ports, :in_ports_size]

  @type t :: %__MODULE__{
          name: String.t(),
          description: String.t(),
          effects: [keyword()],
          in_ports: [atom()],
          out_ports: [atom()],
          in_ports_size: integer()
        }

  @enforce_keys @data
  defstruct @data
end
