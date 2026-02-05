defmodule AtomemoPluginSdk.ModelDefinitionTest do
  use ExUnit.Case

  import AtomemoPluginSdk.TestHelpers

  alias AtomemoPluginSdk.ModelDefinition

  describe "changeset/2" do
    test "creates a basic model definition successfully" do
      attrs = %{
        name: "openai_gpt41",
        display_name: %{"en_US" => "GPT-4.1"},
        description: %{"en_US" => "A powerful LLM model"},
        icon: "🧠",
        model_type: "llm",
        input_modalities: ["text"],
        output_modalities: ["text"],
        pricing: %{
          "currency" => "USD",
          "input" => 0.00001,
          "output" => 0.00003
        },
        unsupported_parameters: ["json_schema", "parallel_tool_calls"]
      }

      changeset = ModelDefinition.changeset(%ModelDefinition{}, attrs)
      assert changeset.valid?

      model = Ecto.Changeset.apply_changes(changeset)
      assert model.name == "openai_gpt41"
      assert model.display_name == %{"en_US" => "GPT-4.1"}
      assert model.description == %{"en_US" => "A powerful LLM model"}
      assert model.icon == "🧠"
      assert model.model_type == :llm
      assert model.input_modalities == [:text]
      assert model.output_modalities == [:text]
      assert model.pricing["currency"] == "USD"
      assert model.unsupported_parameters == ["json_schema", "parallel_tool_calls"]
    end

    test "uses defaults when optional fields are omitted" do
      attrs = %{
        name: "openai_gpt41_mini",
        display_name: %{"en_US" => "GPT-4.1-mini"},
        description: %{"en_US" => "A smaller LLM model"},
        icon: "🤖",
        input_modalities: [:text],
        output_modalities: [:text]
      }

      changeset = ModelDefinition.changeset(%ModelDefinition{}, attrs)
      assert changeset.valid?

      model = Ecto.Changeset.apply_changes(changeset)
      assert model.model_type == :llm
      assert model.default_endpoint == nil
      assert model.pricing == nil
      assert model.override_parameters == nil
      assert model.unsupported_parameters == []
    end

    test "returns error when required fields are missing" do
      attrs = %{
        name: "openai_gpt41"
      }

      changeset = ModelDefinition.changeset(%ModelDefinition{}, attrs)
      refute changeset.valid?

      assert %{
               display_name: ["can't be blank"],
               description: ["can't be blank"],
               icon: ["can't be blank"],
               input_modalities: ["can't be blank"],
               output_modalities: ["can't be blank"]
             } = errors_on(changeset)
    end

    test "returns error when model_type is invalid" do
      attrs = %{
        name: "openai_gpt41",
        display_name: %{"en_US" => "GPT-4.1"},
        description: %{"en_US" => "A powerful LLM model"},
        icon: "🧠",
        model_type: "invalid",
        input_modalities: [:text],
        output_modalities: [:text]
      }

      changeset = ModelDefinition.changeset(%ModelDefinition{}, attrs)
      refute changeset.valid?
      assert %{model_type: ["is invalid"]} = errors_on(changeset)
    end

    test "returns error when name format is invalid" do
      attrs = %{
        name: "__invalid",
        display_name: %{"en_US" => "GPT-4.1"},
        description: %{"en_US" => "A powerful LLM model"},
        icon: "🧠",
        input_modalities: [:text],
        output_modalities: [:text]
      }

      changeset = ModelDefinition.changeset(%ModelDefinition{}, attrs)
      refute changeset.valid?
      assert %{name: [error]} = errors_on(changeset)
      assert error =~ "must start with a letter"
    end

    test "accepts valid name formats" do
      valid_names = [
        "openai_gpt41",
        "openai-gpt41",
        "myModel123",
        "validName",
        "openrouter/openai_gpt41"
      ]

      for valid_name <- valid_names do
        attrs = %{
          name: valid_name,
          display_name: %{"en_US" => "GPT-4.1"},
          description: %{"en_US" => "A powerful LLM model"},
          icon: "🧠",
          input_modalities: [:text],
          output_modalities: [:text]
        }

        changeset = ModelDefinition.changeset(%ModelDefinition{}, attrs)
        assert changeset.valid?
        model = Ecto.Changeset.apply_changes(changeset)
        assert model.name == valid_name
      end
    end
  end
end
