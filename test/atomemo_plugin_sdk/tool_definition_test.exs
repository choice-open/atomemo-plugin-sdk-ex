defmodule AtomemoPluginSdk.ToolDefinitionTest do
  use ExUnit.Case

  import AtomemoPluginSdk.TestHelpers

  alias AtomemoPluginSdk.ToolDefinition

  describe "changeset/2" do
    test "creates a basic tool definition successfully" do
      attrs = %{
        name: "say_hello",
        display_name: %{"en_US" => "Say Hello"},
        description: %{"en_US" => "Says hello to the user"}
      }

      changeset = ToolDefinition.changeset(%ToolDefinition{}, attrs)
      assert changeset.valid?

      tool = Ecto.Changeset.apply_changes(changeset)
      assert tool.name == "say_hello"
      assert tool.display_name == %{"en_US" => "Say Hello"}
      assert tool.description == %{"en_US" => "Says hello to the user"}
      assert tool.locator_list == %{}
      assert tool.resource_mapping == %{}
    end

    test "returns error when name is missing" do
      attrs = %{
        display_name: %{"en_US" => "Say Hello"},
        description: %{"en_US" => "Says hello to the user"}
      }

      changeset = ToolDefinition.changeset(%ToolDefinition{}, attrs)
      refute changeset.valid?
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "returns error when name format is invalid" do
      attrs = %{
        name: "__invalid",
        display_name: %{"en_US" => "Say Hello"},
        description: %{"en_US" => "Says hello to the user"}
      }

      changeset = ToolDefinition.changeset(%ToolDefinition{}, attrs)
      refute changeset.valid?
      assert %{name: [error]} = errors_on(changeset)
      assert error =~ "must start with a letter"
    end

    test "accepts valid name formats" do
      valid_names = [
        "say_hello",
        "say-hello",
        "myTool123",
        "validName"
      ]

      for valid_name <- valid_names do
        attrs = %{
          name: valid_name,
          display_name: %{"en_US" => "Say Hello"},
          description: %{"en_US" => "Says hello to the user"}
        }

        changeset = ToolDefinition.changeset(%ToolDefinition{}, attrs)
        assert changeset.valid?
        tool = Ecto.Changeset.apply_changes(changeset)
        assert tool.name == valid_name
      end
    end

    test "can have parameters and settings" do
      attrs = %{
        name: "test_tool",
        display_name: %{"en_US" => "Test Tool"},
        description: %{"en_US" => "A test tool"},
        parameters: [
          %{
            type: "string",
            name: "message",
            display_name: %{"en_US" => "Message"}
          }
        ],
        settings: [
          %{
            type: "number",
            name: "timeout",
            display_name: %{"en_US" => "Timeout"}
          }
        ]
      }

      changeset = ToolDefinition.changeset(%ToolDefinition{}, attrs)
      assert changeset.valid?

      tool = Ecto.Changeset.apply_changes(changeset)
      assert length(tool.parameters) == 1
      assert length(tool.settings) == 1
    end
  end
end
