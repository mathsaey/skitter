defmodule Skitter.Master do
  @moduledoc """
  """

  def app do
    :skitter_master
  end

  def get_env(key, default \\ nil) do
    Application.get_env(app(), key, default)
  end
end
