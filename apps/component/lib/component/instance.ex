defmodule Skitter.Component.Instance do
  @moduledoc false

  @data [:state, :component]

  @type t :: %__MODULE__{
          state: struct(),
          component: module()
        }

  @enforce_keys @data
  defstruct @data
end
