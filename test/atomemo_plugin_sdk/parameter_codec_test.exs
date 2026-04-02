defmodule AtomemoPluginSdk.ParameterCodecTest do
  use ExUnit.Case, async: true

  alias AtomemoPluginSdk.ParameterCodec
  alias AtomemoPluginSdk.ParameterDefinition.Boolean, as: PDBoolean
  alias AtomemoPluginSdk.ParameterDefinition.CredentialId, as: PDCredentialId
  alias AtomemoPluginSdk.ParameterDefinition.String, as: PDString
  alias AtomemoPluginSdk.ParameterError, as: Error
  alias AtomemoPluginSdk.ParameterError.Entry

  describe "validate_default/1" do
    test "returns ok for nil default" do
      definition = %PDBoolean{type: "boolean", default: nil}

      assert :ok = ParameterCodec.validate_default(definition)
    end

    test "returns ok for valid default" do
      definition = %PDString{type: "string", default: "hello"}

      assert :ok = ParameterCodec.validate_default(definition)
    end

    test "returns error when default violates type constraint" do
      definition = %PDString{type: "string", min_length: 10, default: "short"}

      assert {:error, %Error{errors: [%Entry{message: message}]}} =
               ParameterCodec.validate_default(definition)

      assert message =~ "at least 10"
    end

    test "returns error for credential_id when default is provided" do
      definition = %PDCredentialId{type: "credential_id", default: "secret"}

      assert {:error, %Error{errors: [%Entry{message: message}]}} =
               ParameterCodec.validate_default(definition)

      assert message =~ "not allowed"
    end
  end

  describe "cast/2" do
    test "returns ok for valid value" do
      definition = %PDString{type: "string"}

      assert {:ok, "hello"} = ParameterCodec.cast(definition, "hello")
    end

    test "keeps false boolean instead of treating as nil" do
      definition = %PDBoolean{type: "boolean"}

      assert {:ok, false} = ParameterCodec.cast(definition, false)
    end

    test "uses default when input value is nil" do
      definition = %PDString{type: "string", default: "fallback"}

      assert {:ok, "fallback"} = ParameterCodec.cast(definition, nil)
    end

    test "keeps input value when default exists" do
      definition = %PDString{type: "string", default: "fallback"}

      assert {:ok, "actual"} = ParameterCodec.cast(definition, "actual")
    end

    test "returns nil for nil value with no default and not required" do
      definition = %PDString{type: "string"}

      assert {:ok, nil} = ParameterCodec.cast(definition, nil)
    end

    test "decodes json before type validation" do
      definition = %PDString{type: "string", decoder: :json}

      assert {:ok, "hello"} = ParameterCodec.cast(definition, ~s("hello"))
    end

    test "decodes json when decoder is string" do
      definition = %PDString{type: "string", decoder: "json"}

      assert {:ok, "value"} = ParameterCodec.cast(definition, JSON.encode!("value"))
    end

    test "wraps codec error in ParameterError" do
      definition = %PDString{type: "string", name: "field", min_length: 3}

      assert {:error, %Error{errors: [%Entry{path: [], message: message}]}} =
               ParameterCodec.cast(definition, "ab")

      assert message == "should be at least 3 character(s)"
    end

    test "wraps decoder error in ParameterError" do
      definition = %PDString{type: "string", decoder: :json}

      assert {:error, %Error{errors: [%Entry{path: ["decoder"], message: message}]}} =
               ParameterCodec.cast(definition, "{")

      assert message =~ "can't decode to json"
    end

    test "wraps base required error in ParameterError" do
      definition = %PDString{type: "string", name: "field", required: true}

      assert {:error, %Error{errors: [%Entry{path: [], message: "is required."}]}} =
               ParameterCodec.cast(definition, nil)
    end
  end

  describe "cast/3 - opts" do
    test "prefix is applied to codec error" do
      definition = %PDString{type: "string", name: "field", min_length: 3}

      assert {:error, %Error{errors: [%Entry{path: [0]}]}} =
               ParameterCodec.cast(definition, "ab", prefix: 0)
    end

    test "prefix is applied to decoder error" do
      definition = %PDString{type: "string", decoder: :json}

      assert {:error, %Error{errors: [%Entry{path: [1, "decoder"]}]}} =
               ParameterCodec.cast(definition, "{", prefix: 1)
    end

    test "prefix is applied to base validation error" do
      definition = %PDString{type: "string", name: "field", required: true}

      assert {:error, %Error{errors: [%Entry{path: [2]}]}} =
               ParameterCodec.cast(definition, nil, prefix: 2)
    end

    test "string prefix works" do
      definition = %PDString{type: "string", name: "field", min_length: 3}

      assert {:error, %Error{errors: [%Entry{path: ["parent"]}]}} =
               ParameterCodec.cast(definition, "ab", prefix: "parent")
    end

    test "no prefix leaves path unchanged" do
      definition = %PDString{type: "string", name: "field", min_length: 3}

      assert {:error, %Error{errors: [%Entry{path: []}]}} =
               ParameterCodec.cast(definition, "ab")
    end
  end
end
