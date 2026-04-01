defmodule AtomemoPluginSdk.ParameterValidator.ResourceMapperTest do
  use ExUnit.Case, async: true

  alias AtomemoPluginSdk.ParameterDefinition.ResourceMapper, as: PDResourceMapper
  alias AtomemoPluginSdk.ParameterValidator.ResourceMapper, as: PVResourceMapper
  alias AtomemoPluginSdk.ResourceMapper

  describe "validate/3" do
    test "returns ok when value is already ResourceMapper struct" do
      value = %ResourceMapper{mapping_mode: :auto, value: nil}

      assert {:ok, ^value} = PVResourceMapper.validate(%PDResourceMapper{}, value, [])
    end

    test "casts runtime payload into ResourceMapper struct" do
      payload = %{
        "__type__" => "resource_mapper",
        "mapping_mode" => "manual",
        "value" => %{"field_a" => "col_1"}
      }

      assert {:ok, %ResourceMapper{mapping_mode: :manual, value: %{"field_a" => "col_1"}}} =
               PVResourceMapper.validate(%PDResourceMapper{}, payload, [])
    end

    test "returns changeset issues for invalid payload map" do
      assert {:error, issues} =
               PVResourceMapper.validate(
                 %PDResourceMapper{},
                 %{"__type__" => "resource_mapper"},
                 []
               )

      assert [%{path: [:mapping_mode], message: "can't be blank"}] = issues
    end

    test "returns type error for non-map value" do
      assert {:error, %{path: :type, message: "must be an encoded resource mapper payload."}} =
               PVResourceMapper.validate(%PDResourceMapper{}, 1, [])
    end
  end
end
