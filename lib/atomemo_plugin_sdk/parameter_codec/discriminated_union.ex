defimpl AtomemoPluginSdk.ParameterCodec.Codecable,
  for: AtomemoPluginSdk.ParameterDefinition.DiscriminatedUnion do
  alias AtomemoPluginSdk.ParameterCodec
  alias AtomemoPluginSdk.ParameterError, as: Error
  alias AtomemoPluginSdk.ParameterError.Entry

  def cast_for_default(%@for{} = definition, value) do
    @protocol.cast(definition, value)
  end

  def cast(%@for{discriminator: discriminator, any_of: any_of}, value) do
    cond do
      not is_map(value) ->
        {:error, Entry.new("must be an object.")}

      not Map.has_key?(value, discriminator) ->
        {:error, Entry.new("is required.", path: discriminator)}

      true ->
        discriminator_value = Map.get(value, discriminator)

        case find_definition(any_of, discriminator, discriminator_value) do
          nil ->
            {:error,
             Entry.new("no matching definition found for discriminated union.",
               path: discriminator
             )}

          matched ->
            case ParameterCodec.cast(matched, value) do
              {:ok, value} -> {:ok, value}
              {:error, %Error{errors: entries}} -> {:error, entries}
            end
        end
    end
  end

  defp find_definition(any_of, discriminator, discriminator_value) do
    Enum.find(any_of, fn
      %{properties: properties} when is_list(properties) ->
        Enum.any?(properties, fn
          %{name: ^discriminator, constant: ^discriminator_value} -> true
          _ -> false
        end)

      _ ->
        false
    end)
  end
end
