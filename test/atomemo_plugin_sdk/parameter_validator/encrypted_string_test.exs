defmodule AtomemoPluginSdk.ParameterValidator.EncryptedStringTest do
  use ExUnit.Case, async: true

  alias AtomemoPluginSdk.ParameterDefinition.EncryptedString, as: PDEncryptedString
  alias AtomemoPluginSdk.ParameterValidator.EncryptedString, as: PVEncryptedString

  describe "validate/3" do
    test "uses default validator behavior and returns original value" do
      value = "anything"

      assert {:ok, ^value} = PVEncryptedString.validate(%PDEncryptedString{}, value, [])
    end
  end
end
