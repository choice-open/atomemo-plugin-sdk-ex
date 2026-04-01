defmodule AtomemoPluginSdk.ParameterValidator.LLMConfig do
  @moduledoc false

  use AtomemoPluginSdk.ParameterValidator

  alias AtomemoPluginSdk.LLMConfig
  alias AtomemoPluginSdk.ParameterError, as: Error

  @impl true
  def validate(_definition, %{"__type__" => "llm_config"} = llm_config, _opts) do
    case LLMConfig.new(llm_config) do
      {:ok, llm_config} -> {:ok, llm_config}
      {:error, changeset} -> {:error, Error.issues_from_changeset(changeset)}
    end
  end

  def validate(_definition, _llm_config, _opts) do
    {:error, %{path: :type, message: "must be a encoded llm config json payload"}}
  end
end
