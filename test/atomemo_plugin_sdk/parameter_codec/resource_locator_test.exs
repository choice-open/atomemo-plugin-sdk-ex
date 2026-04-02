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

    test "returns error when __type__ is missing" do
      assert {:error, [%Entry{message: "must be an encoded resource locator payload."}]} =
               Codecable.cast(%PDResourceLocator{}, %{"mode_name" => "url"})
    end
  end

  describe "cast_for_internal_default/2" do
    test "accepts ResourceLocator struct" do
      value = %ResourceLocator{mode_name: :list, value: "res_1"}

      assert {:ok, %ResourceLocator{}} =
               Codecable.cast_for_internal_default(%PDResourceLocator{}, value)
    end

    test "rejects non-struct value" do
      assert {:error, [%Entry{message: "must be a %ResourceLocator{} struct."}]} =
               Codecable.cast_for_internal_default(%PDResourceLocator{}, "invalid")
    end
  end
end
