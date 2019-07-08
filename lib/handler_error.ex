# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.HandlerError do
  @moduledoc """
  This module can be raised by handlers.
  """
  alias Skitter.Component

  defexception [:handler, :message, :for]

  @impl true
  def message(%__MODULE__{handler: h, message: m, for: nil}) do
    h = handler_to_string(h)
    "Handler #{h} raised error:\n#{m}"
  end

  def message(%__MODULE__{handler: h, message: m, for: f}) do
    h = handler_to_string(h)
    "Handler #{h} raised error for #{inspect(f)}:\n#{m}"
  end

  defp handler_to_string(%Component{name: name}) when name != nil, do: name
  defp handler_to_string(c = %Component{}), do: inspect(c)
  defp handler_to_string(Component.MetaHandler), do: Meta
  defp handler_to_string(nil), do: ""
end
