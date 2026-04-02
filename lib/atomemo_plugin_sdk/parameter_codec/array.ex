defimpl AtomemoPluginSdk.ParameterCodec.Codecable,
  for: AtomemoPluginSdk.ParameterDefinition.Array do
  alias AtomemoPluginSdk.ParameterCodec
  alias AtomemoPluginSdk.ParameterError, as: Error
  alias AtomemoPluginSdk.ParameterError.Entry

  def cast_for_default(%@for{} = definition, value) do
    @protocol.cast(definition, value)
  end

  def cast(%@for{max_items: max, min_items: min, items: items}, value) do
    cond do
      not is_list(value) ->
        {:error, Entry.new("must be an array (list).")}

      is_integer(max) and length(value) > max ->
        {:error, Entry.new("must have at most #{max} items.")}

      is_integer(min) and length(value) < min ->
        {:error, Entry.new("must have at least #{min} items.")}

      is_nil(items) ->
        {:ok, value}

      true ->
        validate_items(items, value)
    end
  end

  defp validate_items(items, value) do
    value
    |> Enum.with_index()
    |> Enum.reduce({[], []}, fn {item, index}, {values, errors} ->
      case ParameterCodec.cast(items, item, prefix: index) do
        {:ok, casted} -> {[casted | values], errors}
        {:error, %Error{errors: entries}} -> {values, [entries | errors]}
      end
    end)
    |> case do
      {values, []} -> {:ok, Enum.reverse(values)}
      {_values, errors} -> {:error, errors |> Enum.reverse() |> List.flatten()}
    end
  end
end
