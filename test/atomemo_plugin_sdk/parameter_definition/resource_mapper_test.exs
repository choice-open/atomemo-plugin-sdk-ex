defmodule AtomemoPluginSdk.ParameterDefinition.ResourceMapperTest do
  use ExUnit.Case, async: true
  use AtomemoPluginSdk.ParameterDefinition

  import Ecto.Changeset
  import AtomemoPluginSdk.TestHelpers

  alias AtomemoPluginSdk.ParameterDefinition.ResourceMapper, as: PDResourceMapper

  defmodule TestContainer do
    use Ecto.Schema
    use AtomemoPluginSdk.ParameterDefinition

    import Ecto.Changeset

    @primary_key false
    embedded_schema do
      parameters :parameters
    end

    def changeset(container, attrs) do
      container
      |> cast(attrs, [])
      |> cast_parameters(:parameters)
    end
  end

  describe "parameters with resource_mapper type" do
    test "allows default values" do
      assert PDResourceMapper.__allow_default__() == true
    end

    test "can create container with resource_mapper parameter" do
      attrs = %{
        parameters: [
          %{
            type: "resource_mapper",
            name: "field_mapping",
            display_name: %{"en_US" => "Field Mapping"},
            mapping_method: "mapFields"
          }
        ]
      }

      changeset = TestContainer.changeset(%TestContainer{}, attrs)

      assert changeset.valid?
      assert {:ok, container} = apply_action(changeset, :insert)
      assert length(container.parameters) == 1

      [%PDResourceMapper{} = param] = container.parameters
      assert param.type == "resource_mapper"
      assert param.name == "field_mapping"
      assert param.display_name == %{"en_US" => "Field Mapping"}
      assert param.mapping_method == "mapFields"
    end

    test "rejects resource_mapper without mapping_method" do
      attrs = %{
        parameters: [
          %{
            type: "resource_mapper",
            name: "field_mapping",
            display_name: %{"en_US" => "Field Mapping"}
          }
        ]
      }

      changeset = TestContainer.changeset(%TestContainer{}, attrs)

      refute changeset.valid?
      assert %{parameters: [%{mapping_method: ["can't be blank"]}]} = errors_on(changeset)
    end

    test "rejects resource_mapper with empty mapping_method" do
      attrs = %{
        parameters: [
          %{
            type: "resource_mapper",
            name: "field_mapping",
            display_name: %{"en_US" => "Field Mapping"},
            mapping_method: ""
          }
        ]
      }

      changeset = TestContainer.changeset(%TestContainer{}, attrs)

      refute changeset.valid?
      assert %{parameters: [%{mapping_method: ["can't be blank"]}]} = errors_on(changeset)
    end
  end
end
