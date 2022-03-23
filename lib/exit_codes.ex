# Copyright 2018 - 2022, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.ExitCodes do
  @moduledoc """
  Functions which return the various exit codes a Skitter application may return.
  """

  @doc "Returned when the runtime shut down because connection to a remote runtime was lost"
  @spec remote_shutdown :: 4
  def remote_shutdown, do: 4
end
