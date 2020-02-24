# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Handler.Error do
  @moduledoc """
  This exception can be raised by handlers.
  """
  alias Skitter.Component

  defexception [:handler, :message, :for]

  @impl true
  def message(%__MODULE__{handler: h, message: m, for: f}) do
    h = handler_string(h)
    f = for_string(f)
    "Handler #{h}raised error#{f}:\n#{m}"
  end

  defp handler_string(nil), do: ""
  defp handler_string(any), do: handler_to_string(any) <> " "

  defp for_string(nil), do: ""
  defp for_string(any), do: " for " <> for_to_string(any)

  defp for_to_string(%Component{name: name}), do: Atom.to_string(name)
  defp for_to_string(any), do: inspect(any)

  defp handler_to_string(%Component{name: name}) when name != nil, do: name
  defp handler_to_string(c = %Component{}), do: inspect(c)
  defp handler_to_string(Meta), do: Meta
  defp handler_to_string(nil), do: ""
end
