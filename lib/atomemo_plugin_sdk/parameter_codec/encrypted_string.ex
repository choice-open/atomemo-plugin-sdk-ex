defimpl AtomemoPluginSdk.ParameterCodec.Codecable,
  for: AtomemoPluginSdk.ParameterDefinition.EncryptedString do
  alias AtomemoPluginSdk.ParameterError.Entry

  def cast_for_default(%@for{}, _value, _opts) do
    {:error, Entry.new("encrypted_string type does not support internal defaults.")}
  end

  def cast(%@for{}, value, _opts) when is_binary(value), do: {:ok, value}

  def cast(%@for{}, _value, _opts) do
    {:error, Entry.new("must be a string.")}
  end
end
