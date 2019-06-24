# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.HandlerError do
  @moduledoc """
  This module can be raised by handlers.
  """
  defexception [:handler, :message]

  @impl true
  def message(%__MODULE__{handler: handler, message: message}) do
    "Handler `#{handler}` raised error:\n\t#{message}"
  end

  defmacro error(message) do
    quote do
      raise(unquote(__MODULE__), message: unquote(message), handler: __MODULE__)
    end
  end
end
