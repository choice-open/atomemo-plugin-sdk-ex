defmodule AtomemoPluginSdk.ParameterCodec.LLMConfigTest do
  use ExUnit.Case, async: true

  alias AtomemoPluginSdk.LLMConfig
  alias AtomemoPluginSdk.ParameterCodec.Codecable
  alias AtomemoPluginSdk.ParameterDefinition.LLMConfig, as: PDLLMConfig
  alias AtomemoPluginSdk.ParameterError.Entry

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

  describe "cast/2" do
    test "returns ok with LLMConfig struct for valid payload" do
      assert {:ok, %LLMConfig{} = config} = Codecable.cast(%PDLLMConfig{}, @valid_payload)

      assert config.plugin_slug == "demo_plugin"
      assert config.version_slug == "demo_plugin__release__1.0.0"
      assert config.model == "gpt-4.1"
    end

    test "returns changeset errors for invalid payload" do
      payload = %{"__type__" => "llm_config"}

      assert {:error, entries} = Codecable.cast(%PDLLMConfig{}, payload)

      assert is_list(entries)
      paths = Enum.map(entries, & &1.path)
      assert Enum.any?(paths, &(&1 == ["plugin_slug"] || List.last(&1) == "plugin_slug"))
    end

    test "returns error when __type__ is missing" do
      assert {:error, [%Entry{message: "must be a encoded llm config json payload"}]} =
               Codecable.cast(%PDLLMConfig{}, %{"plugin_slug" => "test"})
    end

    test "returns error when value is not a map" do
      assert {:error, [%Entry{message: "must be a encoded llm config json payload"}]} =
               Codecable.cast(%PDLLMConfig{}, "not a map")
    end

    test "returns error when __type__ is wrong" do
      assert {:error, [%Entry{message: "must be a encoded llm config json payload"}]} =
               Codecable.cast(%PDLLMConfig{}, %{"__type__" => "file_ref"})
    end
  end

  describe "cast_for_internal_default/2" do
    test "returns ok for any value" do
      assert {:ok, "anything"} = Codecable.cast_for_internal_default(%PDLLMConfig{}, "anything")
    end
  end
end
