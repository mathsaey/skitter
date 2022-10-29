# Copyright 2018 - 2022, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Invocation do
  @moduledoc """
  Metadata of data being processed.

  It is often necessary to store metadata that belongs to a (set of) tokens. This data is stored
  in the invocation. Strategies have the ability to create new invocations or to add data to an
  invocation.

  This module defines the invocation type and the operations that can be performed on it.
  """

  @typedoc """
  Invocation definition.

  An invocation is either a map which stores metadata belonging to a set of tokens or an atom
  which defines that the data associated with this invocation does not store metadata. This can
  occur in two situations:

  - The data is external. This occurs when a source node receives a message that is not sent
  through Skitter. In this case, the invocation is marked as `:external`. The strategy handling
  the message is responsible for creating a proper invocation.

  - The message is a "meta-message". This occurs when strategies wish to propagate information
  through the workflow that is not data to be processed. When this is the case, the message is
  marked as `:meta`.

  Regular invocation contain an `:_id` field, which contains a unique identifier. This can be used
  to differentiate between invocations created at different points in time.
  """
  @type t() :: %{required(:_id) => reference()} | :external | :meta

  @doc "Create a new regular invocation."
  @spec new() :: t()
  def new, do: %{_id: make_ref()}

  @doc "Create a new meta invocation."
  @spec meta() :: t()
  def meta, do: :meta
end
