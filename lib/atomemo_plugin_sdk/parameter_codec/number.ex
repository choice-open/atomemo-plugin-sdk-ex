defimpl AtomemoPluginSdk.ParameterCodec.Codecable,
  for: AtomemoPluginSdk.ParameterDefinition.Number do
  alias AtomemoPluginSdk.ParameterError.Entry

  def cast_for_default(%@for{} = definition, value, opts) do
    @protocol.cast(definition, value, opts)
  end

  def cast(%@for{type: type, minimum: min, maximum: max}, value, _opts) do
    cond do
      not is_number(value) ->
        {:error, Entry.new("must be a number.")}

      type == "integer" and not is_integer(value) ->
        {:error, Entry.new("must be an integer.")}

      type == "float" and not is_float(value) ->
        {:error, Entry.new("must be a float.")}

      is_number(min) and value < min ->
        {:error, Entry.new("should be greater than or equal to #{min}")}

      is_number(max) and value > max ->
        {:error, Entry.new("should be less than or equal to #{max}")}

      true ->
        {:ok, value}
    end
  end
end
