# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Manager do
  @moduledoc false
  use GenServer

  alias Skitter.Runtime.Handler

  defstruct [:pid, :elem]

  # --- #
  # API #
  # --- #

  def create(proto) do
    {:ok, pid} =
      DynamicSupervisor.start_child(__MODULE__.Supervisor, {__MODULE__, proto})
    %__MODULE__{pid: pid, elem: proto.elem}
  end

  def start_link(proto), do: GenServer.start_link(__MODULE__, proto)

  # ------ #
  # Server #
  # ------ #

  def init(proto) do
    instance = Handler.deploy(proto)
    {:ok, instance}
  end
end

defimpl Inspect, for: Skitter.Runtime.Manager do
  use Skitter.Inspect, prefix: "Manager"

  ignore :pid
  ignore_short :elem
  ignore_empty :elem
  value_only [:elem]
end
