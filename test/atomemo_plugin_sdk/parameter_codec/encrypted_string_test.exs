defmodule AtomemoPluginSdk.ParameterCodec.EncryptedStringTest do
  use ExUnit.Case, async: true

  alias AtomemoPluginSdk.ParameterCodec.Codecable
  alias AtomemoPluginSdk.ParameterDefinition.EncryptedString, as: PDEncryptedString
  alias AtomemoPluginSdk.ParameterError.Entry

  describe "cast/2" do
    test "returns ok when value is a string" do
      assert {:ok, "secret"} = Codecable.cast(%PDEncryptedString{}, "secret")
    end

    test "returns ok for empty string" do
      assert {:ok, ""} = Codecable.cast(%PDEncryptedString{}, "")
    end

    test "returns error when value is not a string" do
      assert {:error, [%Entry{path: [], message: "must be a string."}]} =
               Codecable.cast(%PDEncryptedString{name: "field"}, 123)
    end

    test "returns error when value is a map" do
      assert {:error, [%Entry{message: "must be a string."}]} =
               Codecable.cast(%PDEncryptedString{}, %{})
    end
  end

  describe "cast_for_internal_default/2" do
    test "returns error because encrypted_string defaults are not supported" do
      assert {:error,
              [%Entry{message: "encrypted_string type does not support internal defaults."}]} =
               Codecable.cast_for_internal_default(%PDEncryptedString{}, "anything")
    end

    test "returns error for map value without raising" do
      assert {:error,
              [%Entry{message: "encrypted_string type does not support internal defaults."}]} =
               Codecable.cast_for_internal_default(%PDEncryptedString{}, %{"a" => 1})
    end
  end
end
