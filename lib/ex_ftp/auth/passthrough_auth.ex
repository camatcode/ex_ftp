# SPDX-License-Identifier: Apache-2.0
defmodule ExFTP.Auth.PassthroughAuth do
  @moduledoc """
  When **authenticator** is `ExFTP.Auth.PassthroughAuth`, this authenticator will require credentials,
  but accepts any user and password combination who isn't `root`.

  > #### 🔒 Security {: .error}
  >
  > Don't use `PassthroughAuth` for production servers.

  <!-- tabs-open -->

  ### ⚙️ Configuration

  *Keys*

  * **authenticator**  == `ExFTP.Auth.PassthroughAuth`
  * **authenticator_config** == `%{}`

  *Example*

  ```elixir
    %{
      # ... ,
      authenticator: ExFTP.Auth.PassthroughAuth,
      authenticator_config: %{}
    }
  ```

  #{ExFTP.Doc.related(["`ExFTP.Authenticator`"])}

  #{ExFTP.Doc.resources("section-4")}

  <!-- tabs-close -->
  """
  @behaviour ExFTP.Authenticator

  alias ExFTP.Authenticator

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
  > The server uses this method to short-circuit bad auth calls.

  <!-- tabs-close -->
  """
  @impl Authenticator
  @spec valid_user?(username :: ExFTP.Authenticator.username()) :: boolean
  def valid_user?(username), do: username && not_root?(username)

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

  <!-- tabs-close -->
  """
  @impl Authenticator
  @spec login(
          password :: ExFTP.Authenticator.password(),
          authenticator_state :: ExFTP.Authenticator.authenticator_state()
        ) :: {:ok, ExFTP.Authenticator.authenticator_state()} | {:error, term()}
  def login(_password, %{username: username} = authenticator_state) do
    if not_root?(username), do: {:ok, authenticator_state}, else: {:error, %{}}
  end

  def login(_password, _), do: {:error, %{}}

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

  <!-- tabs-close -->
  """
  @impl Authenticator
  @spec authenticated?(authenticator_state :: Authenticator.authenticator_state()) :: boolean()
  def authenticated?(%{authenticated: authenticated} = _authenticator_state), do: authenticated
  def authenticated?(_authenticator_state), do: false

  defp not_root?(username) when is_bitstring(username) do
    "root" !=
      username
      |> String.downcase()
      |> String.trim()
  end
end
