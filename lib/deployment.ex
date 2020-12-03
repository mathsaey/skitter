# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Deployment do
  @moduledoc """
  Resources available while a workflow processes a stream of data records.

  A deployment is a set of data that refers to all the state that remains available while a
  workflow or a component processes data. This set of data is available accross the Skitter
  cluster while the deployment is available. Therefore, after its creation, the data of a
  deployment is immutable. Typically, a deployment contains references to many `Skitter.Worker`s,
  which contain the state of the various components in the deployment.
  """
  @typedoc """
  Reference to the deployment.
  """
  @type ref :: reference()

  # @type t :: %__MODULE__{
  #         parent: ref() | nil,
  #         data: any(),
  #         ref: ref()
  #       }
end
