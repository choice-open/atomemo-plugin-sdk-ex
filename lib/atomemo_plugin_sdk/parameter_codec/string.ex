defimpl AtomemoPluginSdk.ParameterCodec.Codecable,
  for: AtomemoPluginSdk.ParameterDefinition.String do
  alias AtomemoPluginSdk.ParameterError.Entry

  def cast_for_default(%@for{} = definition, value, opts) do
    @protocol.cast(definition, value, opts)
  end

  def cast(%@for{min_length: min, max_length: max}, value, _opts) do
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
