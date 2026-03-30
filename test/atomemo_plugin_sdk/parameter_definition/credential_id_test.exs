defmodule AtomemoPluginSdk.ParameterDefinition.CredentialIdTest do
  use ExUnit.Case, async: true

  alias AtomemoPluginSdk.ParameterDefinition.CredentialId, as: PDCredentialId

  test "does not allow default values" do
    assert PDCredentialId.__allow_default__() == false
  end
end
