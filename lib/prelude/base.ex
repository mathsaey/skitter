# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Prelude.Base do
  @moduledoc """
  Standard handler definitions.

  Modules in this namespace define the standard handlers defined by skitter.
  """
  @behaviour Skitter.Prelude

  @impl true
  def _load do
    Skitter.Prelude._load_list([
      __MODULE__.Printer
    ])
  end
end

