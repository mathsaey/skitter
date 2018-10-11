# Copyright 2018, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Component.Behaviour do
  @moduledoc false

  @typep instance :: Skitter.Component.Instance.t()
  @typep checkpoint :: Skitter.Component.checkpoint()
  @typep runtime_error :: Skitter.Component.runtime_error()

  @callback __skitter_metadata__ :: Skitter.Component.Metadata.t()

  @callback __skitter_init__(any()) :: {:ok, instance} | runtime_error()
  @callback __skitter_terminate__(instance) :: :ok | runtime_error()

  @callback __skitter_react__(instance, [any()]) ::
              {:ok, instance, [keyword()]}
              | runtime_error()
  @callback __skitter_react_after_failure__(instance, [any()]) ::
              {:ok, instance, [keyword()]}
              | runtime_error()

  @callback __skitter_create_checkpoint__(instance) ::
              {:ok, checkpoint} | runtime_error()
  @callback __skitter_restore_checkpoint__(checkpoint) ::
              {:ok, instance} | runtime_error()
  @callback __skitter_clean_checkpoint__(instance, checkpoint) ::
              :ok | runtime_error()
end
