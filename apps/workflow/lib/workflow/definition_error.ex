defmodule Skitter.Workflow.DefinitionError do
  @moduledoc """
  This error is raised when a workflow definition is invalid.
  """
  defexception [:message]

  @doc """
  Return a quoted raise statement which can be injected by a macro.

  When activated, the statement will raise a DefinitionError with `reason`.
  """
  def inject_error(reason) do
    quote do
      import unquote(__MODULE__)
      raise Skitter.Workflow.DefinitionError, unquote(reason)
    end
  end

  @doc """
  Return a quoted IO.warn statement which can be injected by a macro.

  When activated, the statement will issues a warning with `reason` and `trace`.
  """
  def inject_warning(reason) do
    quote do
      IO.warn(unquote(reason))
    end
  end
end
