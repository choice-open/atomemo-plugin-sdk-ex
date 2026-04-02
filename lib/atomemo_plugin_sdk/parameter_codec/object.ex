defimpl AtomemoPluginSdk.ParameterCodec.Codecable,
  for: AtomemoPluginSdk.ParameterDefinition.Object do
  alias AtomemoPluginSdk.ParameterCodec
  alias AtomemoPluginSdk.ParameterError, as: Error
  alias AtomemoPluginSdk.ParameterError.Entry

  def cast_for_default(%@for{} = definition, value) do
    @protocol.cast(definition, value)
  end

  def cast(%@for{properties: properties, additional_properties: additional_properties}, value)
      when is_map(value) do
    property_names = Enum.map(properties, & &1.name)
    {properties_map, additional_properties_map} = Map.split(value, property_names)

    with {:ok, props} <- validate_properties(properties, properties_map),
         {:ok, addl_props} <-
           validate_additional_properties(additional_properties, additional_properties_map) do
      {:ok, Map.merge(props, addl_props)}
    end
  end

  def cast(%@for{}, _value) do
    {:error, Entry.new("must be an object.")}
  end

  defp validate_properties(properties, properties_map) do
    properties
    |> Enum.reduce({[], []}, fn %{name: name} = property, {values, errors} ->
      value = Map.get(properties_map, name)

      case ParameterCodec.cast(property, value, prefix: name) do
        {:ok, casted} -> {[{name, casted} | values], errors}
        {:error, %Error{errors: entries}} -> {values, [entries | errors]}
      end
    end)
    |> case do
      {values, []} -> {:ok, Map.new(values)}
      {_values, errors} -> {:error, errors |> Enum.reverse() |> List.flatten()}
    end
  end

  defp validate_additional_properties(nil, additional_properties_map) do
    {:ok, additional_properties_map}
  end

  defp validate_additional_properties(additional_properties, additional_properties_map) do
    additional_properties_map
    |> Enum.reduce({[], []}, fn {name, value}, {values, errors} ->
      case ParameterCodec.cast(additional_properties, value, prefix: name) do
        {:ok, casted} -> {[{name, casted} | values], errors}
        {:error, %Error{errors: entries}} -> {values, [entries | errors]}
      end
    end)
    |> case do
      {values, []} -> {:ok, Map.new(values)}
      {_values, errors} -> {:error, errors |> Enum.reverse() |> List.flatten()}
    end
  end
end
