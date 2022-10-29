# Copyright 2018 - 2022, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.StrategyError do
  @moduledoc """
  Error raised by a strategy.

  This error can be raised by a `Skitter.Strategy`. It is used to indicate the strategy
  encountered some unexpected situation.
  """

  defexception [:message, :context]

  @impl true
  def message(%__MODULE__{message: msg, context: cont}) do
    "Raised by #{inspect(cont.strategy)} handling #{inspect(cont.operation)}:\n\t#{msg}"
  end
end
