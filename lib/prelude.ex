# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Prelude do
  @moduledoc """
  Standard component and workflow definitions.

  Skitter ships with a set of built-in components and workflows. These are
  defined in the `Skitter.Prelude` namespace.

  The moduledocs of the various sub-modules of this module are only present for
  documentation purposes.
  """

  @doc false
  @callback _load() :: :ok

  def _load, do: _load_list([__MODULE__.Meta, __MODULE__.Base])
  def _load_list(lst), do: Enum.map(lst, & &1._load())
end
