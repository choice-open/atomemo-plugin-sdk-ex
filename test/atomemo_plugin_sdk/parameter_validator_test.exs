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

  describe "cast/3 - opts passthrough" do
    test "defaults source to :input when not provided" do
      definition = %PDString{type: "string", min_length: 3}

      assert {:error, %Error{source: :input}} = ParameterValidator.cast(definition, "ab")
    end

    test "preserves explicit source in error" do
      definition = %PDString{type: "string", min_length: 3}

      assert {:error, %Error{source: :plugin}} =
               ParameterValidator.cast(definition, "ab", source: :plugin)
    end

    test "prefix is applied to single issue error" do
      definition = %PDString{type: "string", min_length: 3}

      assert {:error, %Error{issues: [%{path: [0, :min]}]}} =
               ParameterValidator.cast(definition, "ab", prefix: 0)
    end

    test "prefix is applied to decoder error" do
      definition = %PDString{type: "string", decoder: :json}

      assert {:error, %Error{issues: [%{path: [1, :decoder]}]}} =
               ParameterValidator.cast(definition, "{", prefix: 1)
    end

    test "prefix is applied to base validation error" do
      definition = %PDString{type: "string", required: true}

      assert {:error, %Error{issues: [%{path: [2, :required]}]}} =
               ParameterValidator.cast(definition, nil, prefix: 2)
    end

    test "prefix and source work together" do
      definition = %PDString{type: "string", min_length: 3}

      assert {:error, %Error{source: :plugin, issues: [%{path: [0, :min]}]}} =
               ParameterValidator.cast(definition, "ab", source: :plugin, prefix: 0)
    end

    test "no prefix leaves path unchanged" do
      definition = %PDString{type: "string", min_length: 3}

      assert {:error, %Error{issues: [%{path: :min}]}} =
               ParameterValidator.cast(definition, "ab")
    end
  end
end
