defmodule ExFTP.Authenticator do
  @moduledoc """
  A behaviour defining an Authenticator.

  Authenticators are used by the FTP interface to verify login credentials.

  <!-- tabs-open -->

  #{ExFTP.Doc.related(["`ExFTP.Auth.PassthroughAuth`"])}

  #{ExFTP.Doc.resources("section-4")}

  <!-- tabs-close -->
  """

  @typedoc """
  State held onto by the server and modified by the `Authenticator`.

  It may be used by the authenticator to keep stateful values.

  <!-- tabs-open -->

  ### ⚠️ Reminders
  > #### Special Keys {: .tip}
  >
  >   * `authenticated:` `true` will exist if the current user has successfully called `c:login/2`
  >      during this session (and the Authenticator hasn't otherwise removed it)
  >   * `username:` `t:username/0` will exist if the current session has defined the user
  >      (but hasn't necessarily supplied a password)

  #{ExFTP.Doc.related(["`c:login/2`", "`c:authenticated?/1`"])}

  #{ExFTP.Doc.resources()}
  <!-- tabs-close -->

  """
  @type authenticator_state :: %{}

  @typedoc """
  A string representing a user (e.g `"jsmith"`)

  <!-- tabs-open -->

  #{ExFTP.Doc.related(["`c:valid_user?/1`"])}

  #{ExFTP.Doc.resources()}

  <!-- tabs-close -->
  """
  @type username :: String.t()

  @typedoc """
  The string value of the security challenge.

  <!-- tabs-open -->

  ### ⚠️ Reminders
  > #### What is a password, really? {: .tip}
  >
  > A password could be used in the traditional sense; but this could also be a OTP, a hash,
  > or any string value that the user would use to authenticate

  #{ExFTP.Doc.related(["`c:login/2`"])}

  #{ExFTP.Doc.resources()}

  <!-- tabs-close -->
  """
  @type password :: String.t()

  @doc """
  Whether a given username is valid.

  <!-- tabs-open -->

  ### 🏷️ Params
    * **username** :: `t:username/0`

  #{ExFTP.Doc.returns(success: "`true` or `false`")}

  ### 💻 Examples

      iex> alias ExFTP.Auth.PassthroughAuth
      iex> true == PassthroughAuth.valid_user?("jsmith")
      iex> false == PassthroughAuth.valid_user?("root")

  ### ⚠️ Reminders
  > #### 🔒 Security {: .tip}
  >
  > The client will never be informed that a username is invalid.
  >
  > The server uses this method to short-circuit auth calls.

  #{ExFTP.Doc.resources()}

  <!-- tabs-close -->
  """
  @callback valid_user?(username) :: boolean()

  @doc """
  Request a login given a security challenge value.

  <!-- tabs-open -->

  ### 🏷️ Params
    * **password** :: `t:password/0`
    * **authenticator_state** :: `t:authenticator_state/0`

  #{ExFTP.Doc.returns(success: "{:ok, authenticator_state}", failure: "{:error, bad_login_err}")}

  ### 💻 Examples

      iex> alias ExFTP.Auth.PassthroughAuth
      iex> {:ok, auth_state} == PassthroughAuth.login("password", %{username: "jsmith"})
      iex> {:err, _} == PassthroughAuth.login("password", %{})
      iex> # "root" is a disallowed user in PassthroughAuth
      iex> {:err, _} == PassthroughAuth.login("password", %{username: "root"})

  ### ⚠️ Reminders
  > #### Authenticator State {: .tip}
  >
  > The `t:authenticator_state/0` will contain a `:username` key, if one was provided.
  >
  > On success, the **authenticator_state** will be automatically updated to include `authenticated: true`.
  > See `c:authenticated?/1` for more information.

  #{ExFTP.Doc.resources()}

  <!-- tabs-close -->
  """
  @callback login(password, authenticator_state) ::
              {:ok, authenticator_state()} | {:error, term()}

  @doc """
  Given the current state, whether this session is still considered authenticated

  <!-- tabs-open -->

  ### 🏷️ Params
    * **authenticator_state** :: `t:authenticator_state/0`

  #{ExFTP.Doc.returns(success: "`true` or `false`")}

  ### 💻 Examples

      iex> alias ExFTP.Auth.PassthroughAuth
      iex> {:ok, %{authenticated: true} = auth_state} == PassthroughAuth.login("password", %{username: "jsmith"})
      iex> true == PassthroughAuth.authenticated?(auth_state)
      iex> false == PassthroughAuth.authenticated?(%{})

  ### ⚠️ Reminders
  > #### Authenticator State {: .tip}
  >
  > The `t:authenticator_state/0` will contain `authenticated: true`
  > if login has succeeded before in this session.
  >
  > Authenticators may choose to drop that key for their own use cases (e.g if a TTL expires)

  #{ExFTP.Doc.resources()}

  <!-- tabs-close -->
  """
  @callback authenticated?(authenticator_state) :: boolean()
end
