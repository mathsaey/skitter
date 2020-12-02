# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.StrategyError do
  @moduledoc """
  Raised when a strategy encounters an error.

  This error can be raised by a `Skitter.Strategy` hook. It generally occurs when a strategy
  wishes to enforce a certain property (e.g. `Component.require_callback!/3`) which is not met by
  a component.
  """
  defexception [:message]

  def raise(message) do
    raise __MODULE__, message: message
  end
end
