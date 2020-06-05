defmodule Skitter.Worker do
  @moduledoc """
  """

  def app do
    :skitter_worker
  end

  def get_env(key, default \\ nil) do
    Application.get_env(app(), key, default)
  end
end
