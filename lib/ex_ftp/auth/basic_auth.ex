# SPDX-License-Identifier: Apache-2.0
defmodule ExFTP.Auth.BasicAuth do
  @moduledoc """
  When **authenticator** is `ExFTP.Auth.BasicAuth`, this authenticator will call out to an HTTP endpoint that implements
  [HTTP Basic Auth](https://en.wikipedia.org/wiki/Basic_access_authentication){:target=\"_blank\"} with the user's
  supplied credentials.

  > #### 🔒 Security {: .warning}
  >
  > `BasicAuth` is not recommended for situations not protected by SSL.

  <!-- tabs-open -->

  ### ⚙️ Configuration

  *Keys*

  * **authenticator**  == `ExFTP.Auth.BasicAuth`
  * **authenticator_config** :: `t:ExFTP.Auth.BasicAuthConfig.t/0`

  *Example*

  ```elixir
    %{
      authenticator: ExFTP.Auth.BasicAuth,
      authenticator_config: %{
        login_url: "https://httpbin.dev/basic-auth/",
        login_method: :get,
        authenticated_url: "https://httpbin.dev/hidden-basic-auth/",
        authenticated_method: :get,
        authenticated_ttl_ms: 1000 * 60 * 60
      }
    }
  ```

  #{ExFTP.Doc.related(["`ExFTP.Authenticator`"])}

  #{ExFTP.Doc.resources("section-4")}

  <!-- tabs-close -->
  """

  import ExFTP.Auth.Common

  alias ExFTP.Auth.BasicAuthConfig
  alias ExFTP.Authenticator

  @behaviour Authenticator

  @doc """
  Always returns `true`.

  > #### No performance benefit {: .tip}
  > This method is normally used to short-circuit login requests.
  > The performance gain in that short-circuit is negligible for basic auth, so it's not used.
  """
  @impl Authenticator
  @spec valid_user?(username :: ExFTP.Authenticator.username()) :: boolean
  def valid_user?(_username), do: true

  @doc """
  Requests a login using [HTTP Basic Auth](https://en.wikipedia.org/wiki/Basic_access_authentication){:target=\"_blank\"}

  <!-- tabs-open -->

  ### 🏷️ Params
    * **password** :: `t:ExFTP.Authenticator.password/0`
    * **authenticator_state** :: `t:ExFTP.Authenticator.authenticator_state/0`

  ### 🧑‍🍳 Workflow

   * Reads the **authenticator_config**.
   * Receives a password from the client (a username was provided earlier)
   * Calls the **login_url** with HTTP Basic Auth
   * If the response is **HTTP 200**, success. Otherwise, bad login.

  #{ExFTP.Doc.returns(success: "{:ok, authenticator_state}", failure: "{:error, bad_login}")}

  ### 💻 Examples

      iex> alias ExFTP.Auth.BasicAuth
      iex> username = "jsmith"
      iex> password = "password"
      iex> Application.put_env(:ex_ftp, :authenticator, ExFTP.Auth.BasicAuth)
      iex> Application.put_env(:ex_ftp, :authenticator_config, %{
      iex>  login_url: "https://httpbin.dev/basic-auth/" <> username <> "/" <> password,
      iex>  login_method: :get,
      iex>  authenticated_url: "https://httpbin.dev/hidden-basic-auth/" <> username <> "/" <> password,
      iex>  authenticated_method: :get,
      iex>  authenticated_ttl_ms: 1000 * 60 * 60
      iex> })
      iex> {:ok, _} = BasicAuth.login(password, %{username: username})

  #{ExFTP.Doc.related(["`t:ExFTP.Auth.BasicAuthConfig.t/0`", "`t:ExFTP.Auth.Common.login_url/0`", "`t:ExFTP.Auth.Common.login_method/0`"])}

  <!-- tabs-close -->
  """
  @impl Authenticator
  @spec login(
          password :: Authenticator.password(),
          authenticator_state :: Authenticator.authenticator_state()
        ) :: {:ok, Authenticator.authenticator_state()} | {:error, term()}
  def login(password, authenticator_state) do
    with {:ok, config} <- validate_config(BasicAuthConfig) do
      check_login(password, config, authenticator_state)
    end
  end

  @doc """
  Determines whether this session is still considered authenticated

  <!-- tabs-open -->

  ### 🏷️ Params
    * **authenticator_state** :: `t:ExFTP.Authenticator.authenticator_state/0`

  ### 🧑‍🍳 Workflow

   * Reads the **authenticator_config**.
   * If the config has **authenticated_url**,
     * Calls it using HTTP Basic Auth with username and password provided by the user
     * If the response is **HTTP 200**, success. Otherwise, no longer authenticated.
   * If the config does not have **authenticated_url**,
     * investigate the **authenticator_state** for `authenticated: true`

  #{ExFTP.Doc.returns(success: "`true` or `false`")}

  ### 💻 Examples

      iex> alias ExFTP.Auth.BasicAuth
      iex> username = "jsmith"
      iex> password = "password"
      iex> Application.put_env(:ex_ftp, :authenticator, ExFTP.Auth.BasicAuth)
      iex> Application.put_env(:ex_ftp, :authenticator_config, %{
      iex>  login_url: "https://httpbin.dev/basic-auth/" <> username <> "/" <> password,
      iex>  login_method: :get,
      iex>  authenticated_url: "https://httpbin.dev/hidden-basic-auth/" <> username <> "/" <> password,
      iex>  authenticated_method: :get,
      iex>  authenticated_ttl_ms: 1000 * 60 * 60
      iex> })
      iex> {:ok, state} = BasicAuth.login(password, %{username: username})
      iex> BasicAuth.authenticated?(state)
      true

  #{ExFTP.Doc.related(["`t:ExFTP.Auth.BasicAuthConfig.t/0`", "`t:ExFTP.Auth.Common.authenticated_url/0`", "`t:ExFTP.Auth.Common.authenticated_method/0`"])}

  <!-- tabs-close -->
  """
  @impl Authenticator
  @spec authenticated?(authenticator_state :: Authenticator.authenticator_state()) :: boolean()
  def authenticated?(authenticator_state) do
    with {:ok, config} <- validate_config(BasicAuthConfig) do
      check_authentication(config, authenticator_state)
    end
    |> case do
      {:ok, _} -> true
      _ -> false
    end
  end

  defp check_login(
         password,
         %{login_url: url, login_method: http_method} = _config,
         %{username: username} = authenticator_state
       ) do
    Req.request(
      url: url,
      method: http_method,
      redirect: true,
      auth: {:basic, "#{username}:#{password}"}
    )
    |> case do
      {:ok, %{status: 200}} ->
        authenticator_state = Map.put(authenticator_state, :password, password)
        {:ok, authenticator_state}

      _ ->
        {:error, "Did not get a 200 response"}
    end
  end

  defp check_authentication(
         %{authenticated_url: nil} = _config,
         %{authenticated: true} = authenticator_state
       ) do
    {:ok, authenticator_state}
  end

  defp check_authentication(
         %{authenticated_url: url, authenticated_method: http_method} = _config,
         %{username: username, password: password} = authenticator_state
       )
       when not is_nil(url) do
    Req.request(
      url: url,
      method: http_method,
      redirect: true,
      auth: {:basic, "#{username}:#{password}"}
    )
    |> case do
      {:ok, %{status: 200}} ->
        {:ok, authenticator_state}

      _ ->
        {:error, "Did not get a 200 response"}
    end
  end

  defp check_authentication(_config, _authenticator_state) do
    {:error, "Not Authenticated"}
  end
end
