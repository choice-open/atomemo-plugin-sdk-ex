defmodule AtomemoPluginSdk.ParameterValidator.CredentialIdTest do
  use ExUnit.Case, async: true

  alias AtomemoPluginSdk.ParameterDefinition.CredentialId, as: PDCredentialId
  alias AtomemoPluginSdk.ParameterValidator.CredentialId, as: PVCredentialId

  describe "validate/3" do
    test "returns ok for valid UUID" do
      definition = %PDCredentialId{}

      assert {:ok, "550e8400-e29b-41d4-a716-446655440000"} =
               PVCredentialId.validate(definition, "550e8400-e29b-41d4-a716-446655440000", [])
    end

    test "returns error for invalid UUID string" do
      definition = %PDCredentialId{}

      assert {:error, %{path: :type, message: "must be a valid UUID"}} =
               PVCredentialId.validate(definition, "not-a-uuid", [])
    end

    test "returns error when value is not a string" do
      definition = %PDCredentialId{}

      assert {:error, %{path: :type, message: "must be a string representing a UUID"}} =
               PVCredentialId.validate(definition, 123, [])
    end

    test "returns error when value is nil" do
      definition = %PDCredentialId{}

      assert {:error, %{path: :type, message: "must be a string representing a UUID"}} =
               PVCredentialId.validate(definition, nil, [])
    end
  end
end
