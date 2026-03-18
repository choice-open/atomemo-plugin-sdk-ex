defmodule AtomemoPluginSdk.ParameterHydrator do
  @moduledoc """
  Recursively hydrates decoded parameter payloads back into SDK structs.

  This is intended for payloads received over WebSocket, where structs are
  transferred as plain maps. `hydrate/1` accepts maps, lists, or scalar values.
  Unknown shapes are left unchanged.
  """

  alias AtomemoPluginSdk.SdkError

  @known_structs %{
    "file_ref" => AtomemoPluginSdk.FileRef,
    "llm_config" => AtomemoPluginSdk.LLMConfig,
    "resource_locator" => AtomemoPluginSdk.ResourceLocator,
    "resource_mapper" => AtomemoPluginSdk.ResourceMapper
  }
  @known_types Map.keys(@known_structs)

  defguardp is_known_struct(type) when type in @known_types

  def call(parameter) do
    {:ok, hydrate(parameter)}
  rescue
    e in [KeyError, Ecto.InvalidChangesetError] ->
      {:error,
       SdkError.new(:invalid_parameter, "Failed to hydrate parameter: #{Exception.message(e)}")}
  end

  @spec hydrate(term()) :: term()
  def hydrate(list) when is_list(list) do
    Enum.map(list, &hydrate/1)
  end

  def hydrate(struct) when is_struct(struct), do: struct

  def hydrate(%{"__type__" => type} = map) when is_known_struct(type) do
    struct_module = Map.fetch!(@known_structs, type)

    map
    |> struct_module.hydrate_changeset()
    |> Ecto.Changeset.apply_action!(:insert)
  end

  def hydrate(%{__type__: type} = map) when is_known_struct(type) do
    struct_module = Map.fetch!(@known_structs, type)

    map
    |> struct_module.hydrate_changeset()
    |> Ecto.Changeset.apply_action!(:insert)
  end

  def hydrate(map) when is_map(map) do
    Map.new(map, fn {key, value} ->
      {key, hydrate(value)}
    end)
  end

  def hydrate(value), do: value
end
