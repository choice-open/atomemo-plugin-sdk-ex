defmodule AtomemoPluginSdk.ParameterValidatorTest do
  use ExUnit.Case, async: true

  alias AtomemoPluginSdk.ParameterDefinition.Boolean, as: PDBoolean
  alias AtomemoPluginSdk.ParameterDefinition.CredentialId, as: PDCredentialId
  alias AtomemoPluginSdk.ParameterDefinition.String, as: PDString
  alias AtomemoPluginSdk.ParameterValidator
  alias AtomemoPluginSdk.ParameterError, as: Error

  describe "validate_default/1" do
    test "returns ok for nil default" do
      definition = %PDBoolean{type: "boolean", default: nil}

      assert :ok = ParameterValidator.validate_default(definition)
    end

    test "returns error for credential_id when default is provided" do
      definition = %PDCredentialId{type: "credential_id", default: "secret"}

      assert {:error, %Error{message: message, source: :plugin}} =
               ParameterValidator.validate_default(definition)

      assert message == "The default value is not allowed in credential_id parameter definition."
    end
  end

  describe "cast/3" do
    test "uses default when input value is nil" do
      definition = %PDString{type: "string", default: "fallback"}

      assert {:ok, "fallback"} = ParameterValidator.cast(definition, nil)
    end

    test "keeps input value when default exists" do
      definition = %PDString{type: "string", default: "fallback"}

      assert {:ok, "actual"} = ParameterValidator.cast(definition, "actual")
    end

    test "decodes json for runtime input source" do
      definition = %PDString{type: "string", decoder: :json}

      assert {:ok, "hello"} = ParameterValidator.cast(definition, ~s("hello"))
    end

    test "decodes json when decoder is string" do
      definition = %PDString{type: "string", decoder: "json"}

      assert {:ok, "string"} = ParameterValidator.cast(definition, JSON.encode!("string"))
    end

    test "skips decoding for plugin source" do
      definition = %PDString{type: "string", decoder: :json}

      assert {:ok, "not-json"} = ParameterValidator.cast(definition, "not-json", source: :plugin)
    end

    test "normalizes validator map error into ParameterError" do
      definition = %PDString{type: "string", min_length: 3}

      assert {:error, %Error{source: :input, issues: [%{path: :min, message: message}]}} =
               ParameterValidator.cast(definition, "ab")

      assert message == "should be at least 3 character(s)"
    end

    test "normalizes decoder error into ParameterError" do
      definition = %PDString{type: "string", decoder: :json}

      assert {:error, %Error{source: :input, issues: [%{path: :decoder, message: message}]}} =
               ParameterValidator.cast(definition, "{")

      assert message =~ "can't decode to json"
    end
  end
end
