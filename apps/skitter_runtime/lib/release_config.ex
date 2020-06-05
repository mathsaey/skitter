# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.ReleaseConfig do
  @moduledoc """
  Utilities to configure the application environment in `config/releases.exs`
  """

  @doc """
  Store the value of `env` in the application environment of `app` with `key`.
  """
  def load_env(app, key, env, parse \\ fn v -> v end) do
    case System.fetch_env(env) do
      {:ok, val} -> Application.put_env(app, key, parse.(val))
      :error -> :ok
    end
  end

  @doc """
  Set `key` in the application environment of `app` to `bool` if `env` exists
  """
  def if_set(app, key, env, bool) do
    case System.fetch_env(env) do
      {:ok, _} -> Application.put_env(app, key, bool)
      :error -> Application.put_env(app, key, not bool)
    end
  end
end
