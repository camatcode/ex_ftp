defmodule ExFTP.Authenticator do
  @moduledoc """
  A behaviour defining an Authenticator.

  Authenticators are used by the FTP interface to verify login credentials.

  See `ExFTP.Auth.PassthroughAuth` for a simple example.
  """

  @typedoc """
  State held onto by the server and modified by the `Authenticator`.

  It may be used by the authenticator to keep stateful values.

  * `authenticated: true` - Will exist if the current user has successfully called `login/2` during this session
  * `username: String` - Will exist if the current session has defined the user (but has not supplied a password)
  """
  @type authenticator_state :: %{}

  @typedoc """
  A string representing a user (e.g `"jsmith"`)
  """
  @type username :: String.t()

  @typedoc """
  The String value of the security challenge. What this value represents is up to the Authenticator
  """
  @type password :: String.t()

  @doc """
  Whether a given username is valid.

  > #### Security Consideration {: .tip}
  >
  > The client will never be informed that a username is invalid.
  """
  @callback valid_user?(username) :: boolean()

  @doc """
  Request a login given a security challenge value.

  The `authenticator_state` will contain `:username` if one was provided.

  On `{:ok, state}`, the state will be updated to include `authenticated: true`
  """
  @callback login(password, authenticator_state) ::
              {:ok, authenticator_state()} | {:error, term()}

  @doc """
  Given the current state, whether this session is still considered authenticated
  """
  @callback authenticated?(authenticator_state) :: boolean()
end
