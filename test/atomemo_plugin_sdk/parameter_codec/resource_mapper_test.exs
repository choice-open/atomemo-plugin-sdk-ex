defmodule AtomemoPluginSdk.ParameterCodec.ResourceMapperTest do
  use ExUnit.Case, async: true

  alias AtomemoPluginSdk.ParameterCodec.Codecable
  alias AtomemoPluginSdk.ParameterDefinition.ResourceMapper, as: PDResourceMapper
  alias AtomemoPluginSdk.ParameterError.Entry
  alias AtomemoPluginSdk.ResourceMapper

  describe "cast/2" do
    test "casts runtime payload into ResourceMapper struct" do
      payload = %{
        "__type__" => "resource_mapper",
        "mapping_mode" => "manual",
        "value" => %{"field_a" => "col_1"}
      }

      assert {:ok, %ResourceMapper{mapping_mode: :manual, value: %{"field_a" => "col_1"}}} =
               Codecable.cast(%PDResourceMapper{}, payload)
    end

    test "returns changeset errors for invalid payload" do
      assert {:error, entries} =
               Codecable.cast(%PDResourceMapper{}, %{"__type__" => "resource_mapper"})

      assert is_list(entries)
      assert Enum.any?(entries, &(&1.message == "can't be blank"))
    end

    test "returns error for non-map value" do
      assert {:error, [%Entry{path: [], message: message}]} =
               Codecable.cast(%PDResourceMapper{name: "mapper"}, 1)

      assert message == "must be an encoded resource mapper payload."
    end

    test "casts map payload when __type__ is missing" do
      assert {:ok, %ResourceMapper{mapping_mode: :manual, value: nil}} =
               Codecable.cast(%PDResourceMapper{}, %{"mapping_mode" => "manual"})
    end
  end

  describe "cast_for_default/2" do
    test "always rejects because resource_mapper does not support defaults" do
      assert {:error, [%Entry{message: "resource_mapper type does not support defaults."}]} =
               Codecable.cast_for_default(%PDResourceMapper{}, %{
                 "__type__" => "resource_mapper",
                 "mapping_mode" => "auto",
                 "value" => nil
               })

      assert {:error, [%Entry{message: "resource_mapper type does not support defaults."}]} =
               Codecable.cast_for_default(%PDResourceMapper{}, "invalid")
    end
  end
end
