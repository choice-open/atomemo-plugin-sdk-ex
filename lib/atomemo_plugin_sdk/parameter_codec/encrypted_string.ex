defimpl AtomemoPluginSdk.ParameterCodec.Codecable,
  for: AtomemoPluginSdk.ParameterDefinition.EncryptedString do
  alias AtomemoPluginSdk.ParameterError.Entry

  def cast_for_default(%@for{}, _value, _opts) do
    {:error, Entry.new("encrypted_string type does not support internal defaults.")}
  end

  def cast(%@for{}, value, opts) when is_binary(value) do
    encrypted_string_caster =
      Keyword.get(opts, :encrypted_string_caster, fn value -> {:ok, value} end)

    case encrypted_string_caster.(value) do
      {:ok, casted_value} -> {:ok, casted_value}
      {:error, message} when is_binary(message) -> {:error, Entry.new(message)}
    end
  end

  def cast(%@for{}, _value, _opts) do
    {:error, Entry.new("must be a string.")}
  end
end
