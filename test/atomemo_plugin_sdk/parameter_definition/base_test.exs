defmodule AtomemoPluginSdk.ParameterDefinition.BaseTest do
  use ExUnit.Case, async: true

  describe "__using__/1" do
    test "raises on non-boolean allow_default option" do
      module_name = "InvalidAllowDefault#{System.unique_integer([:positive])}"

      code = """
      defmodule #{module_name} do
        use Ecto.Schema
        use AtomemoPluginSdk.ParameterDefinition.Base, allow_default: \"false\"

        @primary_key false
        embedded_schema do
          base_schema()
          field :type, :string, default: \"string\"
        end

        @impl true
        def validate_default(changeset), do: changeset
      end
      """

      assert_raise ArgumentError, ~r/invalid :allow_default option/, fn ->
        Code.compile_string(code)
      end
    end
  end
end
