defimpl AtomemoPluginSdk.ParameterCodec.Codecable,
  for: AtomemoPluginSdk.ParameterDefinition.CredentialId do
  alias AtomemoPluginSdk.ParameterError.Entry

  def cast_for_default(%@for{}, _value) do
    {:error, Entry.new("credential_id type does not support defaults.")}
  end

  def cast(%@for{}, value) when is_binary(value) do
    case Ecto.UUID.cast(value) do
      {:ok, uuid} -> {:ok, uuid}
      :error -> {:error, Entry.new("must be a valid UUID")}
    end
  end

  def cast(%@for{}, _value) do
    {:error, Entry.new("must be a string representing a UUID")}
  end
end
