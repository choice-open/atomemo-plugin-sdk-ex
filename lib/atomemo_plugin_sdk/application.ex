defmodule AtomemoPluginSdk.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = test_children(config_env())
    Supervisor.start_link(children, strategy: :one_for_one, name: AtomemoPluginSdk.Supervisor)
  end

  # Only start the dedicated test task supervisor under the :test environment.
  defp test_children(:test) do
    [
      {Task.Supervisor, name: AtomemoPluginSdk.TestTaskSupervisor}
    ]
  end

  defp test_children(_env), do: []

  defp config_env do
    # This mirrors Mix.config_env/0 but without depending on Mix at runtime.
    Application.get_env(:atomemo_plugin_sdk, :config_env, :prod)
  end
end
