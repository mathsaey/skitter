# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Application.Config do
  @moduledoc false

  @doc """
  Get configuration `key` from the `app` application environment.

  Return `default` if no value is specified.
  """
  def get(app, key, default) do
    Application.get_env(app, key, default)
  end

  @doc """
  Store the value of `env` in the application environment of `app` with `key`.

  `parse` can be used to transform the key (a string obtained from environment variable `env`)
  into an appropriate representation.
  """
  def config_from_env(app, key, env, parse) do
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

  # Use this inside a module to get an easy way to read config for the current application
  defmacro __using__(_opts) do
    quote do
      defp application, do: Application.get_application(__MODULE__)

      def get(key, default \\ nil) do
        unquote(__MODULE__).get(application(), key, default)
      end
    end
  end
end
