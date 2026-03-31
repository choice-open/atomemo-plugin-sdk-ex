defmodule AtomemoPluginSdk.ParameterValidatorTest do
  use ExUnit.Case, async: true

  alias AtomemoPluginSdk.ParameterDefinition.Boolean, as: PDBoolean
  alias AtomemoPluginSdk.ParameterDefinition.CredentialId, as: PDCredentialId
  alias AtomemoPluginSdk.ParameterValidator
  alias AtomemoPluginSdk.ParameterValidator.Error

  describe "validate_default/1" do
    test "returns ok for nil default" do
      definition = %PDBoolean{type: "boolean", default: nil}

      assert :ok = ParameterValidator.validate_default(definition)
    end

    test "returns error for credential_id when default is provided" do
      definition = %PDCredentialId{type: "credential_id", default: "secret"}

      assert :ok = ParameterValidator.validate_default(definition)
    end
  end
end
