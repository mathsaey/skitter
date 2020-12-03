# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Invocation do
  @moduledoc """
  Resources available while a workflow process a single (set of) input(s).

  An invocation contains all the state that is available while a workflow or component processes a
  single data record. Like a deployment, an invocation is globablly available and therefore
  immutable.
  """
  alias Skitter.Deployment

  @typedoc """
  Unique reference to an invocation.
  """
  @type ref :: reference()

  # @type t :: %__MODULE__{
  #   deployment: Deployment.ref(),
  #   data: any(),
  #   ref: ref()
  # }
end
