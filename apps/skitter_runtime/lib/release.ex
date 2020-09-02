# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Release do
  @moduledoc """
  Utilities for dealing with releases.

  This module deals with loading runtime configuration of releases.
  """

  @doc """
  Store the value of `env` in the application environment of `app` with `key`.

  `parse` can be used to transform the key (a string obtained from environment variable `env`)
  into an appropriate representation.
  """
  def config_from_env(app, key, env, parse \\ fn v -> v end) do
    case System.fetch_env(env) do
      {:ok, val} -> Application.put_env(app, key, parse.(val))
      :error -> :ok
    end
  end

  defp bool_if_set(app, key, env, bool) do
    case System.fetch_env(env) do
      {:ok, _} -> Application.put_env(app, key, bool)
      :error -> Application.put_env(app, key, not bool)
    end
  end

  @doc """
  Set `key` to true in `app` if environment variable `env` is defined.

  If `env` is not defined, `key` is set to `false`.
  """
  def config_enabled_if_set(app, key, env) do
    bool_if_set(app, key, env, true)
  end

  @doc """
  Set `key` to true in `app` if environment variable `env` is **not** defined.

  If `env` is not defined, `key` is set to `true`.
  """
  def config_enabled_unless_set(app, key, env) do
    bool_if_set(app, key, env, false)
  end
end
