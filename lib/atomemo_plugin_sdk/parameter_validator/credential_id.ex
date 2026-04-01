defmodule AtomemoPluginSdk.ParameterValidator.CredentialId do
  @moduledoc false

  use AtomemoPluginSdk.ParameterValidator

  @impl true
  def validate(_, value, _opts) when is_binary(value) do
    case Ecto.UUID.cast(value) do
      {:ok, uuid} -> {:ok, uuid}
      :error -> {:error, %{path: [:type], message: "must be a valid UUID"}}
    end
  end

  def validate(_, _, _opts) do
    {:error, %{path: [:type], message: "must be a string representing a UUID"}}
  end
end
