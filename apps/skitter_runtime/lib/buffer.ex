# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Buffer do
  @moduledoc false
  # use Rustler, otp_app: :skitter_runtime, crate: "skitter_buffer"

  # ---- #
  # NIFs #
  # ---- #

  def new(), do: nif_err()
  def read(_), do: nif_err()
  def write(_, _), do: nif_err()

  defp nif_err, do: :erlang.nif_error(:nif_not_loaded)
end
