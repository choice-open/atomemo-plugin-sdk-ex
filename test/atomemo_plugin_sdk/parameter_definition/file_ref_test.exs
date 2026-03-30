defmodule AtomemoPluginSdk.ParameterDefinition.FileRefTest do
  use ExUnit.Case, async: true

  alias AtomemoPluginSdk.ParameterDefinition.FileRef, as: PDFileRef

  test "allows default values" do
    assert PDFileRef.__allow_default__() == true
  end
end
