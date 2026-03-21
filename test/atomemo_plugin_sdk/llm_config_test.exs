defmodule AtomemoPluginSdk.LLMConfigTest do
  use ExUnit.Case, async: true

  alias AtomemoPluginSdk.LLMConfig

  @valid_attrs %{
    "plugin_slug" => "demo_plugin",
    "version_slug" => "demo_plugin__release__1.0.0",
    "model" => "gpt-4.1",
    "credential_instance_id" => "cred_123",
    "model_params" => %{
      "structured_outputs" => true,
      "temperature" => 0.7
    }
  }

  describe "hydrate_changeset/2" do
    test "casts top-level fields and embedded model params" do
      changeset = LLMConfig.hydrate_changeset(%LLMConfig{}, @valid_attrs)

      assert changeset.valid?
      assert Ecto.Changeset.get_field(changeset, :plugin_slug) == "demo_plugin"
      assert Ecto.Changeset.get_field(changeset, :version_slug) == "demo_plugin__release__1.0.0"
      assert Ecto.Changeset.get_field(changeset, :model) == "gpt-4.1"
      assert Ecto.Changeset.get_field(changeset, :credential_instance_id) == "cred_123"

      assert %LLMConfig.ModelParams{
               structured_outputs: true,
               temperature: 0.7
             } = Ecto.Changeset.get_field(changeset, :model_params)
    end

    test "requires plugin_slug, version_slug, model, and model_params" do
      changeset = LLMConfig.hydrate_changeset(%LLMConfig{}, %{})

      refute changeset.valid?

      assert %{
               plugin_slug: ["can't be blank"],
               version_slug: ["can't be blank"],
               model: ["can't be blank"],
               model_params: ["can't be blank"]
             } = errors_on(changeset)
    end
  end

  describe "new/1" do
    test "builds a struct from valid attrs" do
      assert {:ok, %LLMConfig{} = config} = LLMConfig.new(@valid_attrs)

      assert config.plugin_slug == "demo_plugin"
      assert config.version_slug == "demo_plugin__release__1.0.0"
      assert config.model == "gpt-4.1"
      assert config.credential_instance_id == "cred_123"

      assert %LLMConfig.ModelParams{structured_outputs: true, temperature: 0.7} =
               config.model_params
    end

    test "returns changeset errors for invalid attrs" do
      assert {:error, changeset} = LLMConfig.new(%{"model" => "gpt-4.1"})

      assert %{
               plugin_slug: ["can't be blank"],
               version_slug: ["can't be blank"],
               model_params: ["can't be blank"]
             } = errors_on(changeset)
    end
  end

  describe "new!/1" do
    test "returns a struct on success" do
      assert %LLMConfig{} = LLMConfig.new!(@valid_attrs)
    end

    test "raises on invalid attrs" do
      assert_raise Ecto.InvalidChangesetError, fn ->
        LLMConfig.new!(%{})
      end
    end
  end

  describe "JSON.Encoder implementation" do
    test "encodes the runtime type marker and nested model params" do
      llm_config = %LLMConfig{
        plugin_slug: "demo_plugin",
        version_slug: "demo_plugin__release__1.0.0",
        model: "gpt-4.1",
        credential_instance_id: "cred_123",
        model_params: %LLMConfig.ModelParams{
          structured_outputs: true,
          temperature: 0.7
        }
      }

      json =
        llm_config
        |> JSON.encode_to_iodata!()
        |> IO.iodata_to_binary()

      {:ok, decoded} = Jason.decode(json)

      assert decoded["__type__"] == "llm_config"
      assert decoded["plugin_slug"] == "demo_plugin"
      assert decoded["version_slug"] == "demo_plugin__release__1.0.0"
      assert decoded["model"] == "gpt-4.1"
      assert decoded["credential_instance_id"] == "cred_123"
      assert decoded["model_params"]["structured_outputs"] == true
      assert decoded["model_params"]["temperature"] == 0.7
    end
  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
