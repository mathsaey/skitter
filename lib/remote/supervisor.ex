defmodule Skitter.Remote.Supervisor do
  @moduledoc false
  use Supervisor
  alias Skitter.Remote

  def start_link([mode, handlers]) do
    Supervisor.start_link(__MODULE__, [mode, handlers], name: __MODULE__)
  end

  @impl true
  def init([mode, handlers]) do
    children = [
      {Remote.Beacon, mode},
      {Remote.Handler.HandlerDispatcherSupervisor, handlers},
      {Task.Supervisor, name: Remote.TaskSupervisor}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
