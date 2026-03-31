defmodule AtomemoPluginSdk.ParameterValidator.Base do
  use AtomemoPluginSdk.ParameterValidator

  @impl true
  def validate(_definition, value, _opts) do
    {:ok, value}
  end
end
