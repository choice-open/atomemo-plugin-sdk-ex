defmodule AtomemoPluginSdk.ParameterValidator.String do
  @moduledoc false

  use AtomemoPluginSdk.ParameterValidator

  @impl true
  @spec validate(struct(), term(), keyword()) :: AtomemoPluginSdk.ParameterValidator.result()
  def validate(definition, value, opts) do
    path = Keyword.fetch!(opts, :path)

    cond do
      not is_binary(value) ->
        {:error, [%{path: path, message: "must be a string."}]}

      is_integer(definition.min_length) and byte_size(value) < definition.min_length ->
        {:error,
         [
           %{
             path: path,
             message: "should be at least #{definition.min_length} character(s)"
           }
         ]}

      is_integer(definition.max_length) and byte_size(value) > definition.max_length ->
        {:error,
         [
           %{
             path: path,
             message: "should be at most #{definition.max_length} character(s)"
           }
         ]}

      true ->
        {:ok, value}
    end
  end
end
