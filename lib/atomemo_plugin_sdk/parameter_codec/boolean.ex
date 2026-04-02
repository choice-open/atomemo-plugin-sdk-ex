defimpl AtomemoPluginSdk.ParameterCodec.Codecable,
  for: AtomemoPluginSdk.ParameterDefinition.Boolean do
  alias AtomemoPluginSdk.ParameterError.Entry

  def cast_for_default(%@for{} = definition, value) do
    @protocol.cast(definition, value)
  end

  def cast(%@for{}, value) do
    if is_boolean(value) do
      {:ok, value}
    else
      {:error, Entry.new("must be a boolean.")}
    end
  end
end
