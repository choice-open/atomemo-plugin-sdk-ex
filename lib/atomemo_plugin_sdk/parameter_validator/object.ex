defmodule AtomemoPluginSdk.ParameterValidator.Object do
  @moduledoc false

  use AtomemoPluginSdk.ParameterValidator

  alias AtomemoPluginSdk.ParameterError, as: Error

  @impl true
  def validate(
        %{properties: properties, additional_properties: additional_properties},
        value,
        opts
      )
      when is_map(value) do
    property_names = Enum.map(properties, & &1.name)
    {properties_map, additional_properties_map} = Map.split(value, property_names)

    with {:ok, properties} <- validate_properties(properties, properties_map, opts),
         {:ok, additional_properties} <-
           validate_additional_properties(additional_properties, additional_properties_map, opts) do
      {:ok, Map.merge(properties, additional_properties)}
    end
  end

  def validate(_, _, _) do
    {:error, %{path: :type, message: "must be an object."}}
  end

  defp validate_properties(properties, properties_map, opts) do
    properties
    |> Enum.reduce({[], []}, fn %{name: name} = property, {values, errors} ->
      value = Map.get(properties_map, name)
      opts = Keyword.put(opts, :prefix, name)

      case cast(property, value, opts) do
        {:ok, casted} -> {[{name, casted} | values], errors}
        {:error, %Error{issues: issues}} -> {values, [issues | errors]}
      end
    end)
    |> case do
      {values, []} -> {:ok, Map.new(values)}
      {_values, errors} -> {:error, errors |> Enum.reverse() |> List.flatten()}
    end
  end

  defp validate_additional_properties(nil, additional_properties_map, _opts) do
    {:ok, additional_properties_map}
  end

  defp validate_additional_properties(additional_properties, additional_properties_map, opts) do
    additional_properties_map
    |> Enum.reduce({[], []}, fn {name, value}, {values, errors} ->
      opts = Keyword.put(opts, :prefix, name)

      case cast(additional_properties, value, opts) do
        {:ok, casted} -> {[{name, casted} | values], errors}
        {:error, %Error{issues: issues}} -> {values, [issues | errors]}
      end
    end)
    |> case do
      {values, []} -> {:ok, Map.new(values)}
      {_values, errors} -> {:error, errors |> Enum.reverse() |> List.flatten()}
    end
  end
end
