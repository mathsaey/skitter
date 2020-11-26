# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Config do
  @moduledoc false

  @doc """
  Get configuration `key` from the application environment.

  Return `default` if no value is specified.
  """
  def get(key, default \\ nil) do
    Application.get_env(:skitter, key, default)
  end

  @doc """
  Store the value of `env` in the application environment with `key`.

  `parse` can be used to transform the key (a string obtained from environment variable `env`)
  into an appropriate representation.
  """
  def config_from_env(key, env, parse) do
    case System.fetch_env(env) do
      {:ok, val} -> Application.put_env(:skitter, key, parse.(val))
      :error -> :ok
    end
  end

  defp bool_if_set(key, env, bool) do
    case System.fetch_env(env) do
      {:ok, _} -> Application.put_env(:skitter, key, bool)
      :error -> Application.put_env(:skitter, key, not bool)
    end
  end

  @doc """
  Set `key` to true if environment variable `env` is defined.

  If `env` is not defined, `key` is set to `false`.
  """
  def config_enabled_if_set(key, env) do
    bool_if_set(key, env, true)
  end

  @doc """
  Set `key` to true if environment variable `env` is **not** defined.

  If `env` is not defined, `key` is set to `true`.
  """
  def config_enabled_unless_set(key, env) do
    bool_if_set(key, env, false)
  end
end
