defmodule Skitter.Application do
  @moduledoc false

  def logo(ansi \\ IO.ANSI.enabled?())
  def logo(true), do: "⬡⬢⬡⬢ #{IO.ANSI.italic()}Skitter#{IO.ANSI.reset()}"
  def logo(false), do: "Skitter"

  def version, do: "v#{Application.spec(:skitter_application, :vsn)}"

  def log_line(application), do: "Skitter #{version()} [#{application}]"
  def banner(application), do: "#{logo()} #{version()} [#{application}]\n"

  defmacro __using__(_opts) do
    quote do
      defp application, do: Application.get_application(__MODULE__)

      defp interactive_skitter_app do
        IO.puts(unquote(__MODULE__).banner(application()))
      end

      defp noninteractive_skitter_app do
        Logger.info(unquote(__MODULE__).log_line(application()))
      end
    end
  end
end
