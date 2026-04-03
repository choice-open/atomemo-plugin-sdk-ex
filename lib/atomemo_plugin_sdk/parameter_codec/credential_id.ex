defimpl AtomemoPluginSdk.ParameterCodec.Codecable,
  for: AtomemoPluginSdk.ParameterDefinition.CredentialId do
  alias AtomemoPluginSdk.ParameterError.Entry

  def cast_for_default(%@for{}, _value, _opts) do
    {:error, Entry.new("credential_id type does not support defaults.")}
  end

  def cast(%@for{}, value, opts) when is_binary(value) do
    credential_id_caster =
      Keyword.get(opts, :credential_id_caster, fn value -> {:ok, value} end)

    case credential_id_caster.(value) do
      {:ok, casted_value} -> {:ok, casted_value}
      {:error, message} when is_binary(message) -> {:error, Entry.new(message)}
    end
  end

  def cast(%@for{}, _value, _opts) do
    {:error, Entry.new("must be a string")}
  end
end
