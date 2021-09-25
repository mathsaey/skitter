# Copyright 2018 - 2021, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Deployment do
  @moduledoc """
  Constant data of an active data processing pipeline.

  A reactive dataflow which is deployed over the cluster has access to an immutable set of data
  which is termed the _deployment_. Each strategy can specify which data to store in the
  deployment in the `c:Skitter.Strategy.Component.deploy/1` hook. The other strategy hooks have
  access to the data stored within the deployment.  Note that a strategy is only able to access
  its own deployment data.
  """

  @type data :: any()
end
