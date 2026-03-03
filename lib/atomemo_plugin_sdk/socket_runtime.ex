defmodule AtomemoPluginSdk.SocketRuntime do
  @moduledoc """
  Top-level supervisor for the plugin Hub WebSocket runtime.

  Starts the HubClient (Slipstream client) and the Task.Supervisor used
  for concurrent tool invocations.
  """

  use Supervisor

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    task_supervisor_name = AtomemoPluginSdk.TaskSupervisor

    hub_client_opts =
      opts
      |> Keyword.take([:plugin_module, :test_mode?])
      |> Keyword.put(:task_supervisor, task_supervisor_name)

    children = [
      {Task.Supervisor, name: task_supervisor_name},
      {AtomemoPluginSdk.SocketRuntime.HubClient, hub_client_opts}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
