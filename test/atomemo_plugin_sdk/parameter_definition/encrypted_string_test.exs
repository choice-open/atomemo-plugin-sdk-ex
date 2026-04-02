defmodule AtomemoPluginSdk.ParameterDefinition.EncryptedStringTest do
  use ExUnit.Case, async: true

  alias AtomemoPluginSdk.ParameterDefinition.EncryptedString, as: PDEncryptedString

  test "do not allow default values" do
    assert PDEncryptedString.__allow_default__() == false
  end
end
