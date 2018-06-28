defmodule Skitter.Component.DefinitionError do
  @moduledoc """
  This error is raised when a component definition is invalid.
  """
  defexception [:message]
  def exception(val), do: %__MODULE__{message: val}

  @doc false
  def inject_error(reason) do
    quote do
      import unquote(__MODULE__)
      raise Skitter.Component.DefinitionError, unquote(reason)
    end
  end
end
