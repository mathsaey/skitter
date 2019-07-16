# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Profiler do
  @moduledoc false
  # Optionally use fprof to profile Skitter

  require Logger

  def profile(duration) do
    Logger.info("Profiling for #{duration} seconds")
    :fprof.trace([:start, file: trace_file()])

    spawn(fn ->
      Process.sleep(duration * 1000)
      :fprof.trace([:stop])
      :fprof.profile(file: trace_file())
      File.mkdir_p(profile_path())
      :fprof.analyse(dest: profile_file())
      Logger.info("Finished profiling")
    end)
  end

  defp trace_file do
    "/tmp/skitter_profile_#{Node.self()}.trace" |> String.to_charlist()
  end

  defp profile_path do
    "./profile"
  end

  defp profile_file do
    "#{profile_path()}/#{Node.self()}.profile" |> String.to_charlist()
  end
end
