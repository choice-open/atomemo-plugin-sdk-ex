defmodule AtomemoPluginSdk.ParameterValidatorTest do
  use ExUnit.Case, async: true

  alias AtomemoPluginSdk.ParameterDefinition.Boolean, as: PDBoolean
  alias AtomemoPluginSdk.ParameterDefinition.CredentialId, as: PDCredentialId
  alias AtomemoPluginSdk.ParameterDefinition.String, as: PDString
  alias AtomemoPluginSdk.ParameterValidator
  alias AtomemoPluginSdk.ParameterValidator.Error

  describe "validate_default/1" do
    test "returns ok for nil default" do
      definition = %PDString{type: "string", default: nil}

      assert :ok = ParameterValidator.validate_default(definition)
    end

    test "returns error for credential_id when default is provided" do
      definition = %PDCredentialId{type: "credential_id", default: "secret"}

      assert :ok = ParameterValidator.validate_default(definition)
    end

    test "returns ok when string default is valid" do
      definition = %PDString{type: "string", default: "hello"}

      assert :ok = ParameterValidator.validate_default(definition)
    end

    test "returns error for string type mismatch" do
      definition = %PDString{type: "string", default: 1}

      assert {:error, %Error{issues: [issue], source: :default_definition}} =
               ParameterValidator.validate_default(definition)

      assert issue.path == [:default]
      assert issue.message == "must be a string."
    end

    test "returns error for string max_length violation" do
      definition = %PDString{type: "string", default: "toolong", max_length: 3}

      assert {:error, %Error{issues: [issue], source: :default_definition}} =
               ParameterValidator.validate_default(definition)

      assert issue.path == [:default]
      assert issue.message == "should be at most 3 character(s)"
    end
  end
end
