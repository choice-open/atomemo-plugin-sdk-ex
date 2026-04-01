defmodule AtomemoPluginSdk.ParameterValidator.LLMConfigTest do
  use ExUnit.Case, async: true

  alias AtomemoPluginSdk.LLMConfig
  alias AtomemoPluginSdk.ParameterDefinition.LLMConfig, as: PDLLMConfig
  alias AtomemoPluginSdk.ParameterValidator.LLMConfig, as: PVLLMConfig

  @valid_payload %{
    "__type__" => "llm_config",
    "plugin_slug" => "demo_plugin",
    "version_slug" => "demo_plugin__release__1.0.0",
    "model" => "gpt-4.1",
    "credential_instance_id" => "cred_123",
    "model_params" => %{
      "structured_outputs" => true,
      "temperature" => 0.7
    }
  }

  describe "validate/3" do
    test "returns ok with LLMConfig struct for valid payload" do
      definition = %PDLLMConfig{}

      assert {:ok, %LLMConfig{} = config} =
               PVLLMConfig.validate(definition, @valid_payload, [])

      assert config.plugin_slug == "demo_plugin"
      assert config.version_slug == "demo_plugin__release__1.0.0"
      assert config.model == "gpt-4.1"
    end

    test "returns changeset issues for invalid payload" do
      definition = %PDLLMConfig{}
      payload = %{"__type__" => "llm_config"}

      assert {:error, issues} = PVLLMConfig.validate(definition, payload, [])

      assert is_list(issues)
      paths = Enum.map(issues, & &1.path)
      assert [:plugin_slug] in paths
      assert [:version_slug] in paths
      assert [:model] in paths
    end

    test "returns type error when __type__ is missing" do
      definition = %PDLLMConfig{}

      assert {:error, %{path: :type, message: "must be a encoded llm config json payload"}} =
               PVLLMConfig.validate(definition, %{"plugin_slug" => "test"}, [])
    end

    test "returns type error when value is not a map" do
      definition = %PDLLMConfig{}

      assert {:error, %{path: :type, message: "must be a encoded llm config json payload"}} =
               PVLLMConfig.validate(definition, "not a map", [])
    end

    test "returns type error when value is nil" do
      definition = %PDLLMConfig{}

      assert {:error, %{path: :type, message: "must be a encoded llm config json payload"}} =
               PVLLMConfig.validate(definition, nil, [])
    end

    test "returns type error when __type__ is wrong" do
      definition = %PDLLMConfig{}

      assert {:error, %{path: :type, message: "must be a encoded llm config json payload"}} =
               PVLLMConfig.validate(definition, %{"__type__" => "file_ref"}, [])
    end
  end
end
