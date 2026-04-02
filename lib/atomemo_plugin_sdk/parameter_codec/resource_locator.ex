defimpl AtomemoPluginSdk.ParameterCodec.Codecable,
  for: AtomemoPluginSdk.ParameterDefinition.ResourceLocator do
  alias AtomemoPluginSdk.ParameterError.Entry
  alias AtomemoPluginSdk.ResourceLocator

  def cast_for_default(%@for{} = definition, value) do
    @protocol.cast(definition, value)
  end

  def cast(%@for{}, %{"__type__" => "resource_locator"} = value) do
    case ResourceLocator.new(value) do
      {:ok, resource_locator} -> {:ok, resource_locator}
      {:error, changeset} -> {:error, Entry.new(changeset)}
    end
  end

  def cast(%@for{}, _value) do
    {:error, Entry.new("must be an encoded resource locator payload.")}
  end
end
