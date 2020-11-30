# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Deployment do
  @moduledoc """
  Information store for deployed workflows / components.
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