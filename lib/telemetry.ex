# Copyright 2018 - 2022, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Telemetry do
  @moduledoc """
  Macros to emit Telemetry events.

  Skitter offers the option to disable all telemetry events at compile time. To do this, all
  telemetry events in Skitter are emitted through the use of the macros defined in this module.
  When telemetry is disabled, these macros compile to no-ops.
  """
  defmacro __using__(_) do
    quote do
      alias unquote(__MODULE__)
      require unquote(__MODULE__)
    end
  end

  # Dialyzer does not like compile time values.
  @dialyzer :no_match
  @enabled Application.compile_env(:skitter, :telemetry, false)

  def prefix(name), do: quote(do: [:skitter | unquote(name)])

  defmacro emit(name, measurements, metadata) do
    if @enabled do
      quote do
        :telemetry.execute(unquote(prefix(name)), unquote(measurements), unquote(metadata))
      end
    end
  end

  defmacro wrap(name, metadata, do: body) do
    if @enabled do
      quote do
        :telemetry.span(unquote(prefix(name)), unquote(metadata), fn ->
          result = unquote(body)
          {result, Map.put(unquote(metadata), :result, result)}
        end)
      end
    else
      quote do
        unquote(body)
      end
    end
  end
end
