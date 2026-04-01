defmodule AtomemoPluginSdk.ParameterValidator.Number do
  @moduledoc false

  use AtomemoPluginSdk.ParameterValidator
  alias AtomemoPluginSdk.ParameterDefinition.Number

  @impl true
  def validate(%Number{type: type, minimum: min, maximum: max}, value, _opts) do
    cond do
      not is_number(value) ->
        {:error, %{path: :type, message: "must be a number."}}

      type == "integer" and not is_integer(value) ->
        {:error, %{path: :type, message: "must be an integer."}}

      type == "float" and not is_float(value) ->
        {:error, %{path: :type, message: "must be a float."}}

      is_number(min) and value < min ->
        {:error, %{path: :min, message: "should be greater than or equal to #{min}"}}

      is_number(max) and value > max ->
        {:error, %{path: :max, message: "should be less than or equal to #{max}"}}

      true ->
        {:ok, value}
    end
  end
end
