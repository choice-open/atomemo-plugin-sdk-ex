defmodule AtomemoPluginSdk.ParameterValidator do
  alias AtomemoPluginSdk.ParameterValidator.Error

  @type issue :: Error.issue()
  @type source :: :default_definition | :runtime_input

  @callback validate(struct(), term(), keyword()) ::
              {:ok, any()} | {:error, [issue() | String.t()]}

  defmacro __using__(_opts) do
    quote do
      @behaviour AtomemoPluginSdk.ParameterValidator
      @impl true
      def validate(_sturct, value, _opts) do
        {:ok, value}
      end

      defoverridable validate: 3
    end
  end

  def validate_default(%{default: nil}), do: :ok

  def validate_default(%module{default: default} = definition) do
    opts = [source: :default_definition, type_module: module]

    if module.__allow_default__() do
      case validate(definition, default, opts) do
        {:ok, _} -> :ok
        {:error, issues} -> {:error, Error.new(issues, opts)}
      end
    else
      {:error,
       Error.new(
         "The default value is not allowed in #{definition.type} parameter definition.",
         opts
       )}
    end
  end

  defp validate(definition, default, opts) do
    definition
    |> validator_module()
    |> apply(:validate, [definition, default, opts])
  end

  defp validator_module(%module{}) do
    module
    |> Module.split()
    |> Enum.map(fn
      "ParameterDefinition" -> "ParameterValidator"
      segment -> segment
    end)
    |> Module.concat()
  end
end
