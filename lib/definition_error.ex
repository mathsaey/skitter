defmodule Skitter.DefinitionError do
  @moduledoc """
  This error is raised when a definition is invalid.
  """
  defexception [:message]

  @doc """
  Return a quoted raise statement which can be injected by a macro.

  When activated, the statement will raise a DefinitionError with `reason`.
  """
  def inject_error(reason) do
    quote do
      import unquote(__MODULE__)
      raise Skitter.DefinitionError, unquote(reason)
    end
  end
end
