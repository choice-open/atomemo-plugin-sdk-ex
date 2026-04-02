defimpl AtomemoPluginSdk.ParameterCodec.Codecable,
  for: AtomemoPluginSdk.ParameterDefinition.EncryptedString do
  alias AtomemoPluginSdk.ParameterError.Entry

  def cast_for_internal_default(%@for{}, _value) do
    {:error, Entry.new("encrypted_string type does not support internal defaults.")}
  end

  def cast(%@for{}, value) when is_binary(value), do: {:ok, value}

  def cast(%@for{}, _value) do
    {:error, Entry.new("must be a string.")}
  end
end
