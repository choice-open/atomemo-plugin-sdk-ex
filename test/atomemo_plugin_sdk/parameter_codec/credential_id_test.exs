defmodule AtomemoPluginSdk.ParameterCodec.CredentialIdTest do
  use ExUnit.Case, async: true

  alias AtomemoPluginSdk.ParameterCodec.Codecable
  alias AtomemoPluginSdk.ParameterDefinition.CredentialId, as: PDCredentialId
  alias AtomemoPluginSdk.ParameterError.Entry

  @valid_uuid "550e8400-e29b-41d4-a716-446655440000"

  describe "cast/2" do
    test "returns ok for valid UUID" do
      definition = %PDCredentialId{}

      assert {:ok, @valid_uuid} = Codecable.cast(definition, @valid_uuid)
    end

    test "returns error for invalid UUID string" do
      definition = %PDCredentialId{name: "cred"}

      assert {:error, [%Entry{path: [], message: "must be a valid UUID"}]} =
               Codecable.cast(definition, "not-a-uuid")
    end

    test "returns error when value is not a string" do
      definition = %PDCredentialId{name: "cred"}

      assert {:error, [%Entry{path: [], message: "must be a string representing a UUID"}]} =
               Codecable.cast(definition, 123)
    end

    test "returns error when value is a list" do
      definition = %PDCredentialId{name: "cred"}

      assert {:error, [%Entry{message: "must be a string representing a UUID"}]} =
               Codecable.cast(definition, [@valid_uuid])
    end
  end

  describe "cast_for_internal_default/2" do
    test "returns error because credential_id defaults are not supported" do
      assert {:error, [%Entry{message: "credential_id type does not support defaults."}]} =
               Codecable.cast_for_internal_default(%PDCredentialId{}, "anything")
    end

    test "returns error for map value without raising" do
      assert {:error, [%Entry{message: "credential_id type does not support defaults."}]} =
               Codecable.cast_for_internal_default(%PDCredentialId{}, %{"a" => 1})
    end
  end
end
