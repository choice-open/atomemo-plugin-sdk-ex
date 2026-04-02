defmodule AtomemoPluginSdk.ParameterDefinition.StringTest do
  use ExUnit.Case, async: true

  import AtomemoPluginSdk.TestHelpers

  alias AtomemoPluginSdk.ParameterDefinition.String, as: PDString

  test "allows default values" do
    assert PDString.__allow_default__() == true
  end

  describe "changeset/2" do
    test "rejects negative max_length" do
      changeset = PDString.changeset(%PDString{}, %{type: "string", max_length: -1})

      refute changeset.valid?
      assert %{max_length: ["must be greater than or equal to 0"]} = errors_on(changeset)
    end

    test "rejects negative min_length" do
      changeset = PDString.changeset(%PDString{}, %{type: "string", min_length: -1})

      refute changeset.valid?
      assert %{min_length: ["must be greater than or equal to 0"]} = errors_on(changeset)
    end

    test "rejects max_length smaller than min_length" do
      changeset = PDString.changeset(%PDString{}, %{type: "string", min_length: 5, max_length: 3})

      refute changeset.valid?

      assert %{max_length: ["max_length must be greater than or equal to min_length"]} =
               errors_on(changeset)
    end
  end
end
