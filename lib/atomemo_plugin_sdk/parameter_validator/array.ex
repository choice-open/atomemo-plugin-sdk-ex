defmodule AtomemoPluginSdk.ParameterValidator.Array do
  use AtomemoPluginSdk.ParameterValidator

  alias AtomemoPluginSdk.ParameterError, as: Error

  @impl true
  def validate(%{max_items: max, min_items: min, items: items}, value, opts)
      when is_list(value) do
    cond do
      is_integer(max) and length(value) > max ->
        {:error, %{path: :max_items, message: "must have at most #{max} items."}}

      is_integer(min) and length(value) < min ->
        {:error, %{path: :min_items, message: "must have at least #{min} items."}}

      is_nil(items) ->
        {:ok, value}

      true ->
        validate_items(items, value, opts)
    end
  end

  def validate(_definition, _value, _opts) do
    {:error, %{path: :type, message: "must be an array (list)."}}
  end

  defp validate_items(items, value, opts) do
    value
    |> Enum.with_index()
    |> Enum.reverse()
    |> Enum.reduce({[], []}, fn {item, index}, {values, errors} ->
      case cast(items, item, opts) do
        {:ok, casted} ->
          {[casted | values], errors}

        {:error, %Error{issues: issues}} ->
          indexed_issues = Enum.map(issues, &%{&1 | path: [index | List.wrap(&1.path)]})
          {values, errors ++ indexed_issues}
      end
    end)
    |> case do
      {values, []} -> {:ok, values}
      {_values, errors} -> {:error, errors}
    end
  end
end
