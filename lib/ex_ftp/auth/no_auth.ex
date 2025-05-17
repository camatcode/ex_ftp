# SPDX-License-Identifier: Apache-2.0
defmodule ExFTP.Auth.NoAuth do
  @moduledoc """
  When **authenticator** is `ExFTP.Auth.NoAuth`, this authenticator will completely ignore any supplied credentials and
  assume everything is authenticated.

  > #### 🔒 Security {: .error}
  >
  > Don't use `NoAuth` for production servers.

  <!-- tabs-open -->

  ### ⚙️ Configuration

  *Keys*

  * **authenticator**  == `ExFTP.Auth.NoAuth`
  * **authenticator_config** == `%{}`

  *Example*

  ```elixir
    %{
      # ... ,
      authenticator: ExFTP.Auth.NoAuth,
      authenticator_config: %{}
    }
  ```

  #{ExFTP.Doc.related(["`ExFTP.Authenticator`"])}

  #{ExFTP.Doc.resources("section-4")}

  <!-- tabs-close -->
  """

  alias ExFTP.Authenticator
  @behaviour Authenticator

  @doc """
  Always returns true

  <!-- tabs-open -->

  ### 🏷️ Params
    * **username** :: `t:ExFTP.Authenticator.username/0`

  #{ExFTP.Doc.returns(success: "`true`")}

  ### 💻 Examples

      iex> alias ExFTP.Auth.NoAuth
      iex> NoAuth.valid_user?("jsmith")
      true
      iex> NoAuth.valid_user?("root")
      true

  <!-- tabs-close -->
  """
  @impl Authenticator
  @spec valid_user?(username :: Authenticator.username()) :: boolean
  def valid_user?(_username), do: true

  @doc """
  Login will always succeed.

  <!-- tabs-open -->

  ### 🏷️ Params
    * **password** :: `t:ExFTP.Authenticator.password/0`
    * **authenticator_state** :: `t:ExFTP.Authenticator.authenticator_state/0`

  #{ExFTP.Doc.returns(success: "{:ok, authenticator_state}")}

  ### 💻 Examples

      iex> alias ExFTP.Auth.NoAuth
      iex> {:ok, _auth_state} = NoAuth.login("password", %{username: "jsmith"})
      iex> {:ok, _} = NoAuth.login("password", %{})
      iex> {:ok, _} = NoAuth.login("password", %{username: "root"})

  <!-- tabs-close -->
  """
  @impl Authenticator
  @spec login(
          password :: Authenticator.password(),
          authenticator_state :: Authenticator.authenticator_state()
        ) :: {:ok, Authenticator.authenticator_state()} | {:error, term()}
  def login(_password, authenticator_state),
    do: {:ok, authenticator_state}

  @doc """
  Assumes the user is always authenticated

  <!-- tabs-open -->

  ### 🏷️ Params
    * **authenticator_state** :: `t:ExFTP.Authenticator.authenticator_state/0`

  #{ExFTP.Doc.returns(success: "`true`")}

  ### 💻 Examples

      iex> alias ExFTP.Auth.NoAuth
      iex> NoAuth.authenticated?(%{authenticated: true})
      true
      iex> NoAuth.authenticated?(%{})
      true

  #{ExFTP.Doc.resources("section-4")}

  <!-- tabs-close -->
  """
  @impl Authenticator
  @spec authenticated?(authenticator_state :: Authenticator.authenticator_state()) :: boolean()
  def authenticated?(_authenticator_state), do: true
end
