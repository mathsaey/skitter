# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Proxy do
  @moduledoc """
  Proxy for a deployed `Skitter.Workflow`

  When workflow is deployed using `Skitter.deploy/1`, a proxy is returned. This proxy is a
  representation of the workflow which can be used to send data to the deployed worklfow or stop
  it.
  """

  @opaque t :: %__MODULE__{pid: pid()}
  defstruct [:pid, :name]
end

defimpl Inspect, for: Skitter.Proxy do
  use Skitter.Inspect, prefix: "Proxy", named: true

  ignore_empty(:pid)

  match(:pid, pid, _) do
    pid
    |> :erlang.pid_to_list()
    |> to_string()
    |> String.trim_leading("<")
    |> String.trim_trailing(">")
  end
end
