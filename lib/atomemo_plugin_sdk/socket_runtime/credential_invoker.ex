defmodule AtomemoPluginSdk.SocketRuntime.CredentialInvoker do
  @moduledoc """
  Handles credential authentication with timeout support.
  """

  require Logger

  alias AtomemoPluginSdk.CredentialDefinition
  alias AtomemoPluginSdk.SdkError

  @default_timeout_ms 5_000

  @doc """
  Invokes credential authentication with timeout protection.

  Returns `{:ok, spec}` on success or `{:error, reason}` on failure/timeout.
  """
  def authenticate(%CredentialDefinition{} = cred_def, args) do
    timeout_ms = @default_timeout_ms
    task = Task.async(fn -> do_authenticate(cred_def, args) end)

    case Task.yield(task, timeout_ms) || Task.shutdown(task, 5_000) do
      {:ok, result} ->
        result

      nil ->
        Logger.warning(
          "[#{inspect(__MODULE__)}] Credential '#{cred_def.name}' authentication timed out after #{timeout_ms}ms"
        )

        {:error, SdkError.new(:timeout, "Credential '#{cred_def.name}' authentication timed out")}

      {:exit, reason} ->
        Logger.error(
          "[#{inspect(__MODULE__)}] Credential '#{cred_def.name}' authentication exited: #{inspect(reason)}"
        )

        {:error, SdkError.new(:crash, "Credential '#{cred_def.name}' authentication failed")}
    end
  end

  defp do_authenticate(%CredentialDefinition{} = cred_def, args) do
    case call_credential_authenticate(cred_def, args) do
      {:ok, _spec} = ok_tuple ->
        ok_tuple

      {:error, error} when is_map(error) ->
        Logger.error(
          "[#{inspect(__MODULE__)}] Failed to authenticate credential '#{cred_def.name}': #{inspect(error)}"
        )

        {:error, error}
    end
  end

  defp call_credential_authenticate(%CredentialDefinition{authenticate: nil}, _args) do
    {:error, SdkError.new(:not_supported, "auth_spec not supported")}
  end

  defp call_credential_authenticate(%CredentialDefinition{authenticate: fun} = _cred_def, args)
       when is_function(fun, 1) do
    try do
      result = fun.(args)

      case result do
        {:ok, spec} when is_map(spec) ->
          {:ok, spec}

        {:ok, other} ->
          {:error, SdkError.new(:invalid_return, "Unexpected return value: #{inspect(other)}")}

        {:error, error} when is_non_struct_map(error) ->
          {:error, error}

        {:error, message} when is_binary(message) ->
          {:error, %{"message" => message}}

        other ->
          {:error, SdkError.new(:invalid_return, "Unexpected return value: #{inspect(other)}")}
      end
    rescue
      err ->
        {:error,
         SdkError.new(
           :exception,
           "Exception in credential authenticate: #{Exception.message(err)}"
         )}
    catch
      kind, reason ->
        {:error,
         SdkError.new(
           :exception,
           "Caught #{kind} in credential authenticate: #{inspect(reason)}"
         )}
    end
  end

  defp call_credential_authenticate(%CredentialDefinition{} = _cred_def, _args) do
    {:error,
     SdkError.new(
       :invalid_credential_authenticate,
       "authenticate must be a function with arity 1"
     )}
  end
end
