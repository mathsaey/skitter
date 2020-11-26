# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.StrategyError do
  @moduledoc """
  This error can be raised by a strategy implementation.
  """
  defexception [:message]

  def raise(message) do
    raise __MODULE__, message: message
  end
end
