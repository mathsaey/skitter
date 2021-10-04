# Copyright 2018 - 2021, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Port do
  @moduledoc """
  Input/output interface of skitter workflows and components.

  The ports of a component/workflow determine its external interface. This
  module defines the port type.
  """

  @typedoc "A port is defined by its name, which is stored as an atom."
  @type t() :: atom()

  @typedoc "A port is associated with an index."
  @type index() :: non_neg_integer()
end
