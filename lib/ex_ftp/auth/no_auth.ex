# SPDX-License-Identifier: Apache-2.0
defmodule ExFTP.Auth.NoAuth do
  @moduledoc """
  An implementation of `ExFTP.Authenticator` which allows anyone, with or without a username or password

  <!-- tabs-open -->

  ### ⚙️ Configuration

  > #### Elixir {: .info}
  > `NoAuth` only requires `authenticator` to be set to `ExFTP.Auth.NoAuth`
  >
  > ```elixir
  >     config :ex_ftp,
  >       ....
  >       authenticator: ExFTP.Auth.NoAuth,
  >       ....
  > ```

  ### ⚠️ Reminders
  > #### 🔒 Security {: .tip}
  >
  > `NoAuth` is not recommended for publicly facing deployment servers

  #{ExFTP.Doc.related(["`ExFTP.Authenticator`"])}

  #{ExFTP.Doc.resources("section-4")}

  <!-- tabs-close -->
  """

  alias ExFTP.Authenticator
  @behaviour Authenticator

  @impl Authenticator
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

  #{ExFTP.Doc.resources("section-4")}

  <!-- tabs-close -->
  """
  @spec valid_user?(username :: ExFTP.Authenticator.username()) :: boolean
  def valid_user?(_username), do: true

  @impl Authenticator
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

  #{ExFTP.Doc.resources("section-4")}

  <!-- tabs-close -->
  """
  @spec login(
          password :: ExFTP.Authenticator.password(),
          authenticator_state :: ExFTP.Authenticator.authenticator_state()
        ) :: {:ok, ExFTP.Authenticator.authenticator_state()} | {:error, term()}
  def login(_password, authenticator_state),
    do: {:ok, authenticator_state}

  @impl Authenticator
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
  def authenticated?(_authenticator_state), do: true
end
