defmodule AtomemoPluginSdk.ParameterValidator.String do
  @moduledoc false

  use AtomemoPluginSdk.ParameterValidator
  alias AtomemoPluginSdk.ParameterDefinition.String, as: PDString

  @impl true
  def validate(%PDString{min_length: min, max_length: max}, value, _opts) do
    cond do
      not is_binary(value) ->
        {:error, [%{path: :type, message: "must be a string."}]}

      is_integer(min) and String.length(value) < min ->
        {:error, %{path: :min, message: "should be at least #{min} character(s)"}}

      is_integer(max) and String.length(value) > max ->
        {:error, %{path: :max, message: "should be at most #{max} character(s)"}}

      true ->
        {:ok, value}
    end
  end
end
