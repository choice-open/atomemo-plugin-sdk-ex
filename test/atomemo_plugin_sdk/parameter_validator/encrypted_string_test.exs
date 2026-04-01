defmodule AtomemoPluginSdk.ParameterValidator.EncryptedStringTest do
  use ExUnit.Case, async: true

  alias AtomemoPluginSdk.ParameterDefinition.EncryptedString, as: PDEncryptedString
  alias AtomemoPluginSdk.ParameterValidator.EncryptedString, as: PVEncryptedString

  describe "validate/3" do
    test "returns ok when value is a string" do
      value = "anything"

      assert {:ok, ^value} = PVEncryptedString.validate(%PDEncryptedString{}, value, [])
    end

    test "returns error when value is not a string" do
      assert {:error, %{path: :type, message: "must be a string."}} =
               PVEncryptedString.validate(%PDEncryptedString{}, 123, [])
    end
  end
end
