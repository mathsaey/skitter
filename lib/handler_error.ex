# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.HandlerError do
  @moduledoc """
  This module can be raised by handlers.
  """
  alias Skitter.Component

  defexception [:handler, :component, :message]

  @impl true
  def message(%__MODULE__{handler: h, component: c, message: m}) do
    h = comp_to_string(h)
    c = comp_to_string(c)
    "Handler #{h} raised error for component #{c}:\n#{m}"
  end

  defp comp_to_string(%Component{name: name}) when name != nil, do: name
  defp comp_to_string(c = %Component{}), do: inspect(c)
  defp comp_to_string(Component.MetaHandler), do: Meta
  defp comp_to_string(nil), do: ""
end
