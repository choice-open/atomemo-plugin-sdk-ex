defimpl AtomemoPluginSdk.ParameterCodec.Codecable,
  for: AtomemoPluginSdk.ParameterDefinition.ResourceLocator do
  alias AtomemoPluginSdk.ParameterError.Entry
  alias AtomemoPluginSdk.ResourceLocator

  def cast_for_internal_default(%@for{}, %ResourceLocator{} = value) do
    case value |> Map.from_struct() |> ResourceLocator.new() do
      {:ok, resource_locator} -> {:ok, resource_locator}
      {:error, changeset} -> {:error, Entry.new(changeset)}
    end
  end

  def cast_for_internal_default(%@for{}, _value) do
    {:error, Entry.new("must be a %ResourceLocator{} struct.")}
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
