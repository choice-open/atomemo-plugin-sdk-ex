defimpl AtomemoPluginSdk.ParameterCodec.Codecable,
  for: AtomemoPluginSdk.ParameterDefinition.EncryptedString do
  alias AtomemoPluginSdk.ParameterError.Entry

  def cast_for_internal_default(%@for{} = definition, value) do
    @protocol.cast(definition, value)
  end

  def cast(%@for{}, value) when is_binary(value), do: {:ok, value}

  def cast(%@for{}, _value) do
    {:error, Entry.new("must be a string.")}
  end
end
