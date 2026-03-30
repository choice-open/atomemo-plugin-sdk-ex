defmodule AtomemoPluginSdk.ParameterDefinition.EncryptedStringTest do
  use ExUnit.Case, async: true

  alias AtomemoPluginSdk.ParameterDefinition.EncryptedString, as: PDEncryptedString

  test "allows default values" do
    assert PDEncryptedString.__allow_default__() == true
  end
end
