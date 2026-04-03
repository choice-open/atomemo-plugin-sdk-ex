defmodule AtomemoPluginSdk.ParameterDefinition.ResourceLocatorTest do
  use ExUnit.Case, async: true
  use AtomemoPluginSdk.ParameterDefinition

  import Ecto.Changeset
  import AtomemoPluginSdk.TestHelpers

  alias AtomemoPluginSdk.ParameterDefinition.ResourceLocator, as: PDResourceLocator

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

  describe "parameters with resource_locator type" do
    test "does not allow default values" do
      assert PDResourceLocator.__allow_default__() == false
    end

    test "can create container with resource_locator parameter with list mode" do
      attrs = %{
        parameters: [
          %{
            type: "resource_locator",
            name: "test_resource",
            display_name: %{"en_US" => "Test Resource"},
            modes: [
              %{
                type: "list",
                display_name: %{"en_US" => "Select from list"},
                placeholder: %{"en_US" => "Choose..."},
                search_list_method: "getResources",
                searchable: true
              }
            ]
          }
        ]
      }

      changeset = TestContainer.changeset(%TestContainer{}, attrs)

      assert changeset.valid?
      assert {:ok, container} = apply_action(changeset, :insert)
      assert length(container.parameters) == 1

      [%PDResourceLocator{} = param] = container.parameters
      assert param.type == "resource_locator"
      assert param.name == "test_resource"
      assert param.display_name == %{"en_US" => "Test Resource"}
      assert length(param.modes) == 1

      [%PDResourceLocator.ListMode{} = mode] = param.modes
      assert mode.type == "list"
      assert mode.display_name == %{"en_US" => "Select from list"}
      assert mode.placeholder == %{"en_US" => "Choose..."}
      assert mode.search_list_method == "getResources"
      assert mode.searchable == true
    end

    test "can create container with resource_locator parameter with url mode" do
      attrs = %{
        parameters: [
          %{
            type: "resource_locator",
            name: "test_resource",
            display_name: %{"en_US" => "Test Resource"},
            modes: [
              %{
                type: "url",
                display_name: %{"en_US" => "Enter URL"},
                placeholder: %{"en_US" => "https://..."},
                extract_value: %{regex: "https://example.com/(.+)"}
              }
            ]
          }
        ]
      }

      changeset = TestContainer.changeset(%TestContainer{}, attrs)

      assert changeset.valid?
      assert {:ok, container} = apply_action(changeset, :insert)

      [%PDResourceLocator{} = param] = container.parameters
      [%PDResourceLocator.UrlMode{} = mode] = param.modes
      assert mode.type == "url"
      assert mode.display_name == %{"en_US" => "Enter URL"}
      assert mode.extract_value == %{regex: "https://example.com/(.+)"}
    end

    test "can create container with resource_locator parameter with id mode" do
      attrs = %{
        parameters: [
          %{
            type: "resource_locator",
            name: "test_resource",
            display_name: %{"en_US" => "Test Resource"},
            modes: [
              %{
                type: "id",
                display_name: %{"en_US" => "Enter ID"},
                placeholder: %{"en_US" => "abc123..."}
              }
            ]
          }
        ]
      }

      changeset = TestContainer.changeset(%TestContainer{}, attrs)

      assert changeset.valid?
      assert {:ok, container} = apply_action(changeset, :insert)

      [%PDResourceLocator{} = param] = container.parameters
      [%PDResourceLocator.IdMode{} = mode] = param.modes
      assert mode.type == "id"
      assert mode.display_name == %{"en_US" => "Enter ID"}
      assert mode.placeholder == %{"en_US" => "abc123..."}
    end

    test "can create container with resource_locator parameter with multiple modes" do
      attrs = %{
        parameters: [
          %{
            type: "resource_locator",
            name: "test_resource",
            display_name: %{"en_US" => "Test Resource"},
            modes: [
              %{
                type: "list",
                display_name: %{"en_US" => "Select from list"},
                search_list_method: "getResources"
              },
              %{
                type: "url",
                display_name: %{"en_US" => "Enter URL"}
              },
              %{
                type: "id",
                display_name: %{"en_US" => "Enter ID"}
              }
            ]
          }
        ]
      }

      changeset = TestContainer.changeset(%TestContainer{}, attrs)

      assert changeset.valid?
      assert {:ok, container} = apply_action(changeset, :insert)

      [%PDResourceLocator{} = param] = container.parameters
      assert length(param.modes) == 3

      [list_mode, url_mode, id_mode] = param.modes
      assert %PDResourceLocator.ListMode{type: "list"} = list_mode
      assert %PDResourceLocator.UrlMode{type: "url"} = url_mode
      assert %PDResourceLocator.IdMode{type: "id"} = id_mode
    end

    test "rejects resource_locator without modes" do
      attrs = %{
        parameters: [
          %{
            type: "resource_locator",
            name: "test_resource",
            display_name: %{"en_US" => "Test Resource"},
            modes: []
          }
        ]
      }

      changeset = TestContainer.changeset(%TestContainer{}, attrs)

      refute changeset.valid?
      assert %{parameters: [%{modes: ["must have at least one mode"]}]} = errors_on(changeset)
    end

    test "rejects list mode without search_list_method" do
      attrs = %{
        parameters: [
          %{
            type: "resource_locator",
            name: "test_resource",
            display_name: %{"en_US" => "Test Resource"},
            modes: [
              %{
                type: "list",
                display_name: %{"en_US" => "Select from list"}
              }
            ]
          }
        ]
      }

      changeset = TestContainer.changeset(%TestContainer{}, attrs)

      refute changeset.valid?
      assert %{parameters: [%{modes: [%{search_list_method: _}]}]} = errors_on(changeset)
    end

    test "allows list mode without display_name" do
      attrs = %{
        parameters: [
          %{
            type: "resource_locator",
            name: "test_resource",
            modes: [
              %{
                type: "list",
                search_list_method: "getResources"
              }
            ]
          }
        ]
      }

      changeset = TestContainer.changeset(%TestContainer{}, attrs)

      assert changeset.valid?
      assert {:ok, container} = apply_action(changeset, :insert)
      [%PDResourceLocator{} = param] = container.parameters
      [%PDResourceLocator.ListMode{} = mode] = param.modes
      assert mode.display_name == nil
    end

    test "allows url mode without display_name" do
      attrs = %{
        parameters: [
          %{
            type: "resource_locator",
            name: "test_resource",
            modes: [
              %{
                type: "url"
              }
            ]
          }
        ]
      }

      changeset = TestContainer.changeset(%TestContainer{}, attrs)

      assert changeset.valid?
      assert {:ok, container} = apply_action(changeset, :insert)
      [%PDResourceLocator{} = param] = container.parameters
      [%PDResourceLocator.UrlMode{} = mode] = param.modes
      assert mode.display_name == nil
    end

    test "allows id mode without display_name" do
      attrs = %{
        parameters: [
          %{
            type: "resource_locator",
            name: "test_resource",
            modes: [
              %{
                type: "id"
              }
            ]
          }
        ]
      }

      changeset = TestContainer.changeset(%TestContainer{}, attrs)

      assert changeset.valid?
      assert {:ok, container} = apply_action(changeset, :insert)
      [%PDResourceLocator{} = param] = container.parameters
      [%PDResourceLocator.IdMode{} = mode] = param.modes
      assert mode.display_name == nil
    end
  end
end
