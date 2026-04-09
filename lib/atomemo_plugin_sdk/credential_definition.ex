defmodule AtomemoPluginSdk.CredentialDefinition do
  @moduledoc """
  Credential definition struct, used to describe a credential and how to
  authenticate with it.

  For OAuth2 credentials (`oauth2: true`), `oauth2_grant_type` selects
  `:authorization_code` (default) or `:client_credentials`; it is included in
  the serialized plugin definition for Hub.
  """

  use Ecto.Schema
  use AtomemoPluginSdk.ParameterDefinition

  import Ecto.Changeset

  @derive {JSON.Encoder,
           except: [
             :authenticate,
             :oauth2_build_authorize_url,
             :oauth2_get_token,
             :oauth2_refresh_token
           ]}
  @primary_key false
  embedded_schema do
    field :type, :string
    field :name, :string
    field :display_name, AtomemoPluginSdk.I18nEntry
    field :description, AtomemoPluginSdk.I18nEntry
    field :icon, :string
    field :oauth2, :boolean, default: false

    field :oauth2_grant_type, Ecto.Enum,
      values: [:authorization_code, :client_credentials],
      default: :authorization_code

    # Non-serialized field for performing authentication / building auth_spec
    field :authenticate, :any, virtual: true
    field :oauth2_build_authorize_url, :any, virtual: true
    field :oauth2_get_token, :any, virtual: true
    field :oauth2_refresh_token, :any, virtual: true
    parameters :parameters
  end

  @type t() :: %__MODULE__{
          name: String.t(),
          display_name: AtomemoPluginSdk.I18nEntry.t() | nil,
          description: AtomemoPluginSdk.I18nEntry.t() | nil,
          icon: String.t() | nil,
          oauth2: boolean(),
          oauth2_grant_type: :authorization_code | :client_credentials,
          parameters: [AtomemoPluginSdk.ParameterDefinition.t()],
          authenticate: authenticate_fun(),
          oauth2_build_authorize_url: oauth2_callback_fun(),
          oauth2_get_token: oauth2_callback_fun(),
          oauth2_refresh_token: oauth2_callback_fun()
        }

  @type authenticate_fun() :: (args :: map() -> {:ok, map()} | {:error, any()})
  @type oauth2_callback_fun() :: (args :: map() -> {:ok, map()} | {:error, any()})

  def changeset(credential, attrs) do
    credential
    |> cast(attrs, [
      :name,
      :display_name,
      :description,
      :icon,
      :oauth2,
      :oauth2_grant_type,
      :authenticate,
      :oauth2_build_authorize_url,
      :oauth2_get_token,
      :oauth2_refresh_token
    ])
    |> validate_required([:name])
    |> cast_parameters(:parameters)
  end
end
