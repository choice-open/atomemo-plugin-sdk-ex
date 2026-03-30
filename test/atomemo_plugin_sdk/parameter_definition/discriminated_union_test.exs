defmodule AtomemoPluginSdk.ParameterDefinition.DiscriminatedUnionTest do
  use ExUnit.Case, async: true

  alias AtomemoPluginSdk.ParameterDefinition.DiscriminatedUnion, as: PDDiscriminatedUnion

  test "allows default values" do
    assert PDDiscriminatedUnion.__allow_default__() == true
  end
end
