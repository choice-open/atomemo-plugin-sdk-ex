defmodule AtomemoPluginSdk.PluginDefinitionTest do
  use ExUnit.Case

  import AtomemoPluginSdk.TestHelpers

  alias AtomemoPluginSdk.FileRef
  alias AtomemoPluginSdk.PluginDefinition

  describe "new/1" do
    test "creates a basic plugin definition successfully" do
      attrs = %{
        lang: :elixir,
        name: "my_plugin",
        display_name: %{"en_US" => "My Plugin"},
        description: %{"en_US" => "My awesome plugin"},
        icon: "🔌",
        author: "John Doe",
        email: "john@example.com",
        repo: "https://github.com/example/my_plugin",
        version: "1.0.0"
      }

      assert {:ok, definition} = PluginDefinition.new(attrs)
      assert definition.name == "my_plugin"
      assert definition.display_name == %{"en_US" => "My Plugin"}
      assert definition.description == %{"en_US" => "My awesome plugin"}
      assert definition.icon == "🔌"
      assert definition.author == "John Doe"
      assert definition.email == "john@example.com"
      assert definition.repo == "https://github.com/example/my_plugin"
      assert definition.version == "1.0.0"
      assert definition.locales == ["en_US"]
    end

    test "creates a plugin definition with custom locales" do
      attrs = %{
        lang: :elixir,
        name: "my_plugin",
        display_name: %{"en_US" => "My Plugin"},
        description: %{"en_US" => "My awesome plugin"},
        icon: "🔌",
        author: "John Doe",
        email: "john@example.com",
        version: "1.0.0",
        locales: ["en_US", "zh_Hans"]
      }

      assert {:ok, definition} = PluginDefinition.new(attrs)
      assert definition.locales == ["en_US", "zh_Hans"]
    end

    test "accepts file_ref default provided as struct" do
      attrs = %{
        lang: :elixir,
        name: "my_plugin",
        display_name: %{"en_US" => "My Plugin"},
        description: %{"en_US" => "My awesome plugin"},
        icon: "🔌",
        author: "John Doe",
        email: "john@example.com",
        version: "1.0.0",
        tools: [
          %{
            name: "tool1",
            parameters: [
              %{
                type: "file_ref",
                name: "file",
                default: %FileRef{source: :mem, content: "abc"}
              }
            ]
          }
        ]
      }

      assert {:ok, definition} = PluginDefinition.new(attrs)
      [%{parameters: [%{default: default}]}] = definition.tools
      assert default["__type__"] == "file_ref"
      assert default["source"] == "mem"
      assert default["content"] == "YWJj"
    end

    test "returns error when required fields are missing" do
      attrs = %{
        name: "my_plugin"
      }

      assert {:error, changeset} = PluginDefinition.new(attrs)
      refute changeset.valid?

      assert %{
               lang: ["can't be blank"],
               display_name: ["can't be blank"],
               description: ["can't be blank"],
               icon: ["can't be blank"],
               author: ["can't be blank"],
               email: ["can't be blank"],
               version: ["can't be blank"]
             } = errors_on(changeset)
    end

    test "returns error when email format is invalid" do
      attrs = %{
        lang: :elixir,
        name: "my_plugin",
        display_name: %{"en_US" => "My Plugin"},
        description: %{"en_US" => "My awesome plugin"},
        icon: "🔌",
        author: "John Doe",
        email: "invalid-email",
        version: "1.0.0"
      }

      assert {:error, changeset} = PluginDefinition.new(attrs)
      refute changeset.valid?
      assert %{email: ["must be a valid email address"]} = errors_on(changeset)
    end

    test "returns error when name format is invalid" do
      attrs = %{
        lang: :elixir,
        name: "__invalid",
        display_name: %{"en_US" => "My Plugin"},
        description: %{"en_US" => "My awesome plugin"},
        icon: "🔌",
        author: "John Doe",
        email: "john@example.com",
        version: "1.0.0"
      }

      assert {:error, changeset} = PluginDefinition.new(attrs)
      refute changeset.valid?
      assert %{name: [error]} = errors_on(changeset)
      assert error =~ "must start with a letter"
    end

    test "accepts valid name formats" do
      valid_names = [
        "my_plugin",
        "my-plugin",
        "myPlugin123",
        "validName"
      ]

      for valid_name <- valid_names do
        attrs = %{
          lang: :elixir,
          name: valid_name,
          display_name: %{"en_US" => "My Plugin"},
          description: %{"en_US" => "My awesome plugin"},
          icon: "🔌",
          author: "John Doe",
          email: "john@example.com",
          version: "1.0.0"
        }

        assert {:ok, definition} = PluginDefinition.new(attrs)
        assert definition.name == valid_name
      end
    end
  end
end
