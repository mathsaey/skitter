defmodule Skitter.Component.DefinitionError do
  @moduledoc """
  This error is raised when a component definition is invalid.
  """
  defexception [:message]
  def exception(val), do: %__MODULE__{message: val}

  @doc """
  Return a quoted raise statement which can be injected by a macro.

  When activated, the statement will raise a DefinitionError with `reason`.
  """
  def inject_error(reason) do
    quote do
      import unquote(__MODULE__)
      raise Skitter.Component.DefinitionError, unquote(reason)
    end
  end
end
