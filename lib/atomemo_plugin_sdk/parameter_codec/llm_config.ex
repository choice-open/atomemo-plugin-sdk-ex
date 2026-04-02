defimpl AtomemoPluginSdk.ParameterCodec.Codecable,
  for: AtomemoPluginSdk.ParameterDefinition.LLMConfig do
  alias AtomemoPluginSdk.LLMConfig
  alias AtomemoPluginSdk.ParameterError.Entry

  def cast_for_default(%@for{}, _value) do
    {:error, Entry.new("llm_config type does not support defaults.")}
  end

  def cast(%@for{}, %{"__type__" => "llm_config"} = llm_config) do
    case LLMConfig.new(llm_config) do
      {:ok, llm_config} -> {:ok, llm_config}
      {:error, changeset} -> {:error, Entry.new(changeset)}
    end
  end

  def cast(%@for{}, _value) do
    {:error, Entry.new("must be a encoded llm config json payload")}
  end
end
