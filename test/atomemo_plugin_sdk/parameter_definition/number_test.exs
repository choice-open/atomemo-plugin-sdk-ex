defmodule AtomemoPluginSdk.ParameterDefinition.NumberTest do
  use ExUnit.Case, async: true

  import AtomemoPluginSdk.TestHelpers

  alias AtomemoPluginSdk.ParameterDefinition.Number, as: PDNumber

  test "allows default values" do
    assert PDNumber.__allow_default__() == true
  end

  describe "changeset/2" do
    test "rejects maximum smaller than minimum" do
      changeset = PDNumber.changeset(%PDNumber{}, %{type: "number", minimum: 5, maximum: 3})

      refute changeset.valid?

      assert %{maximum: ["maximum must be greater than or equal to minimum"]} =
               errors_on(changeset)
    end
  end
end
