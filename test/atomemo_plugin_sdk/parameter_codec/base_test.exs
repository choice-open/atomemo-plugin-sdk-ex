defmodule AtomemoPluginSdk.ParameterCodec.BaseTest do
  use ExUnit.Case, async: true

  alias AtomemoPluginSdk.ParameterCodec.Base
  alias AtomemoPluginSdk.ParameterDefinition.CredentialId, as: PDCredentialId
  alias AtomemoPluginSdk.ParameterDefinition.String, as: PDString
  alias AtomemoPluginSdk.ParameterError.Entry

  describe "cast/2 - decoder integration" do
    test "decodes json before returning value" do
      definition = %PDString{decoder: :json}

      assert {:ok, "hello"} = Base.cast(definition, ~s("hello"))
    end

    test "returns decoder error for invalid json" do
      definition = %PDString{decoder: :json}

      assert {:error, [%Entry{path: ["decoder"], message: message}]} =
               Base.cast(definition, "{")

      assert message =~ "can't decode to json"
    end

    test "passes through value when decoder is nil" do
      definition = %PDString{}

      assert {:ok, "raw"} = Base.cast(definition, "raw")
    end
  end

  describe "cast/2 - default handling" do
    test "returns nil when value is nil and no default" do
      definition = %PDString{}

      assert {:ok, nil} = Base.cast(definition, nil)
    end

    test "returns default when value is nil and default is set" do
      definition = %PDString{default: "fallback"}

      assert {:ok, "fallback"} = Base.cast(definition, nil)
    end

    test "returns original value when value is not nil even with default" do
      definition = %PDString{default: "fallback"}

      assert {:ok, "actual"} = Base.cast(definition, "actual")
    end

    test "returns error when allow_default is false and default is set" do
      definition = %PDCredentialId{type: "credential_id", default: "secret"}

      assert {:error, [%Entry{message: message}]} = Base.cast(definition, nil)
      assert message =~ "not allowed"
    end
  end

  describe "cast/2 - required validation" do
    test "returns error when required is true and value is nil" do
      definition = %PDString{name: "field", required: true}

      assert {:error, [%Entry{path: [], message: "is required."}]} =
               Base.cast(definition, nil)
    end

    test "returns ok when required is true and value is present" do
      definition = %PDString{required: true}

      assert {:ok, "hello"} = Base.cast(definition, "hello")
    end

    test "returns ok when required is false and value is nil" do
      definition = %PDString{required: false}

      assert {:ok, nil} = Base.cast(definition, nil)
    end
  end

  describe "cast/2 - constant validation" do
    test "returns ok when value matches constant" do
      definition = %PDString{constant: "fixed"}

      assert {:ok, "fixed"} = Base.cast(definition, "fixed")
    end

    test "returns error when value does not match constant" do
      definition = %PDString{name: "field", constant: "fixed"}

      assert {:error, [%Entry{path: [], message: "must be the constant value."}]} =
               Base.cast(definition, "other")
    end

    test "skips constant check when constant is nil" do
      definition = %PDString{}

      assert {:ok, "anything"} = Base.cast(definition, "anything")
    end

    test "skips constant check when value is nil" do
      definition = %PDString{constant: "fixed"}

      assert {:ok, nil} = Base.cast(definition, nil)
    end

  describe "cast/2 - enum validation" do
    test "returns ok when value is in enum list" do
      definition = %PDString{enum: ["alpha", "beta"]}

      assert {:ok, "alpha"} = Base.cast(definition, "alpha")
    end

    test "returns error when value is not in enum list" do
      definition = %PDString{name: "field", enum: ["alpha", "beta"]}

      assert {:error, [%Entry{path: [], message: "must be one of the enum values"}]} =
               Base.cast(definition, "gamma")
    end

    test "skips enum check when enum is nil" do
      definition = %PDString{enum: nil}

      assert {:ok, "anything"} = Base.cast(definition, "anything")
    end

    test "skips enum check when value is nil" do
      definition = %PDString{enum: ["alpha"]}

      assert {:ok, nil} = Base.cast(definition, nil)
    end
  end

  describe "cast/2 - validation order" do
    test "required check runs before constant check" do
      definition = %PDString{name: "f", required: true, constant: "fixed"}

      assert {:error, [%Entry{path: [], message: "is required."}]} =
               Base.cast(definition, nil)
    end

    test "decoder runs before default handling" do
      # empty string decodes to nil via JSON, then default kicks in
      definition = %PDString{decoder: :json, default: "fallback"}

      assert {:ok, "fallback"} = Base.cast(definition, "")
    end
  end
end
