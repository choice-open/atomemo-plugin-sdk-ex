defimpl AtomemoPluginSdk.ParameterCodec.Codecable,
  for: AtomemoPluginSdk.ParameterDefinition.ResourceMapper do
  alias AtomemoPluginSdk.ParameterError.Entry
  alias AtomemoPluginSdk.ResourceMapper

  def cast_for_internal_default(%@for{} = definition, value) do
    @protocol.cast(definition, value)
  end

  def cast(%@for{}, %{"__type__" => "resource_mapper"} = value) do
    case ResourceMapper.new(value) do
      {:ok, resource_mapper} -> {:ok, resource_mapper}
      {:error, changeset} -> {:error, Entry.new(changeset)}
    end
  end

  def cast(%@for{}, _value) do
    {:error, Entry.new("must be an encoded resource mapper payload.")}
  end
end
