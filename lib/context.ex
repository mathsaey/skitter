# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Context do
  @moduledoc """
  Container for runtime information.

  Often, there is a need to pass runtime information between callbacks and the runtime
  functionality they request. This context is used for this purpose. It defines an opaque type
  that is runtime-implementation specific which is used to transfer runtime information between
  various pieces of the Skitter runtime system.
  """
  alias Skitter.{Deployment, Workflow}

  @opaque t :: %__MODULE__{
            deployment_ref: Deployment.ref(),
            workflow_ref: reference(),
            workflow_id: Workflow.id()
          }

  defstruct [:deployment_ref, :workflow_ref, :workflow_id]
end
