defmodule AtomemoPluginSdk.ParameterValidator.ResourceLocatorTest do
  use ExUnit.Case, async: true

  alias AtomemoPluginSdk.ParameterDefinition.ResourceLocator, as: PDResourceLocator
  alias AtomemoPluginSdk.ParameterValidator.ResourceLocator, as: PVResourceLocator
  alias AtomemoPluginSdk.ResourceLocator

  describe "validate/3" do
    test "returns ok when value is already ResourceLocator struct" do
      value = %ResourceLocator{mode_name: :list, value: "res_1"}

      assert {:ok, ^value} = PVResourceLocator.validate(%PDResourceLocator{}, value, [])
    end

    test "casts runtime payload into ResourceLocator struct" do
      payload = %{
        "__type__" => "resource_locator",
        "mode_name" => "url",
        "value" => "https://example.com"
      }

      assert {:ok, %ResourceLocator{mode_name: :url, value: "https://example.com"}} =
               PVResourceLocator.validate(%PDResourceLocator{}, payload, [])
    end

    test "returns changeset issues for invalid payload map" do
      assert {:error, issues} =
               PVResourceLocator.validate(
                 %PDResourceLocator{},
                 %{"__type__" => "resource_locator"},
                 []
               )

      assert [%{path: [:mode_name], message: "can't be blank"}] = issues
    end

    test "returns type error for non-map value" do
      assert {:error, %{path: :type, message: "must be an encoded resource locator payload."}} =
               PVResourceLocator.validate(%PDResourceLocator{}, 1, [])
    end
  end
end
