defmodule AtomemoPluginSdk.ParameterCodec.ResourceLocatorTest do
  use ExUnit.Case, async: true

  alias AtomemoPluginSdk.ParameterCodec.Codecable
  alias AtomemoPluginSdk.ParameterDefinition.ResourceLocator, as: PDResourceLocator
  alias AtomemoPluginSdk.ParameterError.Entry
  alias AtomemoPluginSdk.ResourceLocator

  describe "cast/2" do
    test "casts runtime payload into ResourceLocator struct" do
      payload = %{
        "__type__" => "resource_locator",
        "mode_name" => "url",
        "value" => "https://example.com"
      }

      assert {:ok, %ResourceLocator{mode_name: :url, value: "https://example.com"}} =
               Codecable.cast(%PDResourceLocator{}, payload)
    end

    test "returns changeset errors for invalid payload map" do
      assert {:error, entries} =
               Codecable.cast(%PDResourceLocator{}, %{"__type__" => "resource_locator"})

      assert is_list(entries)
      assert Enum.any?(entries, &(&1.message == "can't be blank"))
    end

    test "returns error for non-map value" do
      assert {:error, [%Entry{path: [], message: message}]} =
               Codecable.cast(%PDResourceLocator{name: "loc"}, 1)

      assert message == "must be an encoded resource locator payload."
    end

    test "casts map payload when __type__ is missing" do
      assert {:ok, %ResourceLocator{mode_name: :url, value: nil}} =
               Codecable.cast(%PDResourceLocator{}, %{"mode_name" => "url"})
    end
  end

  describe "cast_for_default/2" do
    test "always rejects because resource_locator does not support defaults" do
      assert {:error, [%Entry{message: "resource_locator type does not support defaults."}]} =
               Codecable.cast_for_default(%PDResourceLocator{}, %{
                 "__type__" => "resource_locator",
                 "mode_name" => "list",
                 "value" => "res_1"
               })

      assert {:error, [%Entry{message: "resource_locator type does not support defaults."}]} =
               Codecable.cast_for_default(%PDResourceLocator{}, "invalid")
    end
  end
end
