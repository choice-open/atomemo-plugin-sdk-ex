defimpl AtomemoPluginSdk.ParameterCodec.Codecable,
  for: AtomemoPluginSdk.ParameterDefinition.ResourceLocator do
  alias AtomemoPluginSdk.ParameterError.Entry
  alias AtomemoPluginSdk.ResourceLocator

  def cast_for_default(%@for{}, _value, _opts) do
    {:error, Entry.new("resource_locator type does not support defaults.")}
  end

  def cast(%@for{}, %{"__type__" => "resource_locator"} = value, _opts) do
    case ResourceLocator.new(value) do
      {:ok, resource_locator} -> {:ok, resource_locator}
      {:error, changeset} -> {:error, Entry.new(changeset)}
    end
  end

  def cast(%@for{}, _value, _opts) do
    {:error, Entry.new("must be an encoded resource locator payload.")}
  end
end
