defimpl AtomemoPluginSdk.ParameterCodec.Codecable,
  for: AtomemoPluginSdk.ParameterDefinition.ResourceMapper do
  alias AtomemoPluginSdk.ParameterError.Entry
  alias AtomemoPluginSdk.ResourceMapper

  def cast_for_default(%@for{} = definition, value, opts) do
    @protocol.cast(definition, value, opts)
  end

  def cast(%@for{}, %{"__type__" => "resource_mapper"} = value, _opts) do
    case ResourceMapper.new(value) do
      {:ok, resource_mapper} -> {:ok, resource_mapper}
      {:error, changeset} -> {:error, Entry.new(changeset)}
    end
  end

  def cast(%@for{}, _value, _opts) do
    {:error, Entry.new("must be an encoded resource mapper payload.")}
  end
end
