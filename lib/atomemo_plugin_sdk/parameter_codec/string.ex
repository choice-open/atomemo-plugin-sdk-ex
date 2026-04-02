defimpl AtomemoPluginSdk.ParameterCodec.Codecable,
  for: AtomemoPluginSdk.ParameterDefinition.String do
  alias AtomemoPluginSdk.ParameterError.Entry

  def cast_for_internal_default(%@for{} = definition, value) do
    @protocol.cast(definition, value)
  end

  def cast(%@for{min_length: min, max_length: max}, value) do
    cond do
      not is_binary(value) ->
        {:error, Entry.new("must be a string.")}

      is_integer(min) and String.length(value) < min ->
        {:error, Entry.new("should be at least #{min} character(s)")}

      is_integer(max) and String.length(value) > max ->
        {:error, Entry.new("should be at most #{max} character(s)")}

      true ->
        {:ok, value}
    end
  end
end
