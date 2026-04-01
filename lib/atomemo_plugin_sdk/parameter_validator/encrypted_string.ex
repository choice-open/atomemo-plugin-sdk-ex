defmodule AtomemoPluginSdk.ParameterValidator.EncryptedString do
  @moduledoc false

  use AtomemoPluginSdk.ParameterValidator

  @impl true
  def validate(_definition, value, _opts) when is_binary(value) do
    {:ok, value}
  end

  def validate(_definition, _value, _opts) do
    {:error, %{path: :type, message: "must be a string."}}
  end
end
