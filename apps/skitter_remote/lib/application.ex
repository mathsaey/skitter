defmodule Skitter.Remote.Application do
  @moduledoc false

  use Application
  alias Skitter.Remote

  @impl true
  def start(_type, _args) do
    children = [
      Remote.Beacon,
      Remote.Handler.Supervisor,
      {Task.Supervisor, name: Remote.TaskSupervisor}
    ]

    opts = [strategy: :one_for_one, name: Remote.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
