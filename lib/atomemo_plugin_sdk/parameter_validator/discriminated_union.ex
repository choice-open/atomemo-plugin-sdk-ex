defmodule AtomemoPluginSdk.ParameterValidator.DiscriminatedUnion do
  @moduledoc false

  use AtomemoPluginSdk.ParameterValidator

  alias AtomemoPluginSdk.ParameterError, as: Error

  @impl true
  def validate(%{discriminator: discriminator, any_of: any_of}, value, opts) when is_map(value) do
    discriminator_value = Map.get(value, discriminator)
    definition = find_definition(any_of, discriminator, discriminator_value)

    cond do
      not Map.has_key?(value, discriminator) ->
        {:error, %{path: discriminator, message: "is required."}}

      !definition ->
        {:error,
         %{path: discriminator, message: "no matching definition found for discriminated union."}}

      true ->
        child_opts = Keyword.delete(opts, :prefix)

        case cast(definition, value, child_opts) do
          {:ok, value} -> {:ok, value}
          {:error, %Error{issues: issues}} -> {:error, issues}
        end
    end
  end

  def validate(_, _, _) do
    {:error, %{path: :type, message: "must be an object."}}
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
