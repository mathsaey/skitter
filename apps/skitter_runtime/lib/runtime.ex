# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime do
  @moduledoc """
  """

  def get_cli_opts, do: Application.get_env(:skitter_runtime, :cli_opts, [])

  defdelegate discover(node), to: Skitter.Runtime.Beacon
  defdelegate publish(atom), to: Skitter.Runtime.Beacon
end
