# Copyright 2018, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

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
