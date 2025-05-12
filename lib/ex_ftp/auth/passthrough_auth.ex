# SPDX-License-Identifier: Apache-2.0
defmodule ExFTP.Auth.PassthroughAuth do
  @moduledoc """
  An implementation of `ExFTP.Authenticator` which permits any user except `"root"`

  <!-- tabs-open -->

  ### ⚠️ Reminders
  > #### Authenticator State {: .tip}
  >
  >   * `authenticated:` `true` will exist if the current user has successfully called `login/2`
  >      during this session
  >   * `username:` `t:ExFTP.Authenticator.username/0` will exist if the current session has defined the user
  >      (but hasn't necessarily supplied a password)

  > #### 🔒 Security {: .tip}
  >
  > `PassThroughAuth` is not recommended for publicly facing deployment servers; as it's only
  > one step better than no auth at all.

  #{ExFTP.Doc.related(["`ExFTP.Authenticator`"])}

  #{ExFTP.Doc.resources("section-4")}

  <!-- tabs-close -->
  """
  alias ExFTP.Authenticator
  @behaviour Authenticator

  @impl Authenticator
  @doc """
  Returns `true` if **username** is anything except `"root"`

  <!-- tabs-open -->

  ### 🏷️ Params
    * **username** :: `t:ExFTP.Authenticator.username/0`

  #{ExFTP.Doc.returns(success: "`true` or `false`")}

  ### 💻 Examples

      iex> alias ExFTP.Auth.PassthroughAuth
      iex> PassthroughAuth.valid_user?("jsmith")
      true
      iex> PassthroughAuth.valid_user?("root")
      false

  ### ⚠️ Reminders
  > #### 🔒 Security {: .tip}
  >
  > The client will never be informed that a username is invalid.
  >
  > The server uses this method to short-circuit auth calls.

  #{ExFTP.Doc.resources("section-4")}

  <!-- tabs-close -->
  """
  @spec valid_user?(username :: ExFTP.Authenticator.username()) :: boolean
  def valid_user?(username), do: not_root?(username)

  @impl Authenticator
  @doc """
  Login will respond `{:ok, unmodified_auth_state}` to anyone but `username: "root"`

  <!-- tabs-open -->

  ### 🏷️ Params
    * **password** :: `t:ExFTP.Authenticator.password/0`
    * **authenticator_state** :: `t:ExFTP.Authenticator.authenticator_state/0`

  #{ExFTP.Doc.returns(success: "{:ok, authenticator_state}", failure: "{:error, bad_login}")}

  ### 💻 Examples

      iex> alias ExFTP.Auth.PassthroughAuth
      iex> {:ok, _auth_state} = PassthroughAuth.login("password", %{username: "jsmith"})
      iex> {:error, _} = PassthroughAuth.login("password", %{})
      iex> # "root" is a disallowed user in PassthroughAuth
      iex> {:error, _} = PassthroughAuth.login("password", %{username: "root"})

  ### ⚠️ Reminders
  > #### Authenticator State {: .tip}
  >
  > The `t:ExFTP.Authenticator.authenticator_state/0` will contain a `:username` key, if one was provided.
  >
  > On success, the **authenticator_state** will be automatically updated to include `authenticated: true`.
  > See `authenticated?/1` for more information.

  #{ExFTP.Doc.resources("section-4")}

  <!-- tabs-close -->
  """
  @spec login(
          password :: ExFTP.Authenticator.password(),
          authenticator_state :: ExFTP.Authenticator.authenticator_state()
        ) :: {:ok, ExFTP.Authenticator.authenticator_state()} | {:error, term()}
  def login(_password, %{username: username} = authenticator_state) do
    if not_root?(username), do: {:ok, authenticator_state}, else: {:error, %{}}
  end

  def login(_password, _), do: {:error, %{}}

  @impl Authenticator
  @doc """
  Assumes the user is still authenticated as long as `authenticated: true`
    still exists in the **authenticator_state**.

  <!-- tabs-open -->

  ### 🏷️ Params
    * **authenticator_state** :: `t:ExFTP.Authenticator.authenticator_state/0`

  #{ExFTP.Doc.returns(success: "`true` or `false`")}

  ### 💻 Examples

      iex> alias ExFTP.Auth.PassthroughAuth
      iex> PassthroughAuth.authenticated?(%{authenticated: true})
      true
      iex> PassthroughAuth.authenticated?(%{})
      false

  #{ExFTP.Doc.resources("section-4")}

  <!-- tabs-close -->
  """
  def authenticated?(%{authenticated: authenticated} = _authenticator_state), do: authenticated
  def authenticated?(_authenticator_state), do: false

  defp not_root?(username) when is_bitstring(username) do
    "root" !=
      String.downcase(username)
      |> String.trim()
  end
end
