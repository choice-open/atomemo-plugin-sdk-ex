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
end
