# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.ImmutableStore do
  @moduledoc """
  Local storage for immutable data.

  Many data elements in skitter are relatively large, need to be present on
  every runtime, and are never changed. This module offers a store which can
  be used to store such data.

  This module uses the erlang `:persistent_term` functionality under the hood.
  It does not support removing items, only storage and retrieval.
  """

  @spec store(any(), any()) :: :ok
  def store(key, val), do: :persistent_term.put({__MODULE__, key}, val)
  @spec get(any()) :: any()
  def get(key), do: :persistent_term.get({__MODULE__, key})
end
