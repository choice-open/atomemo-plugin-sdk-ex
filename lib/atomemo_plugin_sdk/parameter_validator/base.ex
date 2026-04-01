defmodule AtomemoPluginSdk.ParameterValidator.Base do
  use AtomemoPluginSdk.ParameterValidator

  @impl true
  def validate(%{required: required, constant: constant, enum: enum}, value, _opts) do
    with :ok <- validate_required(required, value),
         :ok <- validate_constant(constant, value),
         :ok <- validate_enum(enum, value) do
      {:ok, value}
    end
  end

  defp validate_required(true, nil) do
    {:error, %{path: :required, message: "is required."}}
  end

  defp validate_required(_, _), do: :ok
  defp validate_constant(nil, _), do: :ok
  defp validate_constant(value, value), do: :ok

  defp validate_constant(_, _) do
    {:error, %{path: :constant, message: "must be a constant value."}}
  end

  defp validate_enum(nil, _), do: :ok

  defp validate_enum(enums, value) when is_list(enums) do
    if value in enums do
      :ok
    else
      {:error, %{path: :enum, message: "is not an allowed value."}}
    end
  end
end
