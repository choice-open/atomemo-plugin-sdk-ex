defmodule AtomemoPluginSdk.ParameterValidator.Boolean do
  @moduledoc false

  use AtomemoPluginSdk.ParameterValidator

  @impl true
  def validate(_definition, value, _opts) do
    if is_boolean(value) do
      {:ok, value}
    else
      {:error, %{path: :type, message: "must be a boolean."}}
    end
  end
end
