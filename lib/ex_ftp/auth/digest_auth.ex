# SPDX-License-Identifier: Apache-2.0
defmodule ExFTP.Auth.DigestAuth do
  @moduledoc """
  When **authenticator** is `ExFTP.Auth.DigestAuth`, this authenticator will call out to an HTTP endpoint that
  implements [HTTP Digest Access Auth](https://en.wikipedia.org/wiki/Digest_access_authentication){:target=\"_blank\"}
  with the user's supplied credentials.

  > #### 🔒 Security {: .tip}
  >
  > This can be used in situations where SSL is not available, though be warned, Digest Access is considered
  > an obsolete protocol.

  <!-- tabs-open -->

  ### ⚙️ Configuration

  *Keys*

  * **authenticator**  == `ExFTP.Auth.DigestAuth`
  * **authenticator_config** :: `t:ExFTP.Auth.DigestAuthConfig.t/0`

  *Example*

  ```elixir
    %{
      # ... ,
      authenticator: ExFTP.Auth.DigestAuth,
      authenticator_config: %{
        login_url: "https://httpbin.dev/digest-auth/auth/replace/me/MD5",
        login_method: :get,
        authenticated_url: "https://httpbin.dev/digest-auth/auth/replace/me/MD5",
        authenticated_method: :get,
        authenticated_ttl_ms: 1000 * 60 * 60
      }
    }
  ```

  #{ExFTP.Doc.related(["`ExFTP.Authenticator`"])}

  #{ExFTP.Doc.resources("section-4")}

  <!-- tabs-close -->
  """

  @behaviour ExFTP.Authenticator

  import ExFTP.Auth.Common

  alias ExFTP.Auth.DigestAuthConfig
  alias ExFTP.Authenticator

  @doc """
  Always returns `true`.

  > #### No performance benefit {: .tip}
  > This method is normally used to short-circuit bad login requests.
  > The performance gain in that short-circuit is negligible for this auth, so it's not used.
  """
  @impl Authenticator
  @spec valid_user?(username :: Authenticator.username()) :: boolean
  def valid_user?(_username), do: true

  @doc """
  Requests a login using [HTTP Digest Access Auth](https://en.wikipedia.org/wiki/Digest_access_authentication){:target=\"_blank\"}

  <!-- tabs-open -->

  ### 🏷️ Params
    * **password** :: `t:ExFTP.Authenticator.password/0`
    * **authenticator_state** :: `t:ExFTP.Authenticator.authenticator_state/0`

  ### 🧑‍🍳 Workflow

   * Reads the **authenticator_config**.
   * Receives a password from the client (a username was supplied earlier)
   * Calls the **login_url** - receives **HTTP 401** with digest headers
   * Performs calculation, calls **login_url** with proper headers
   * If the response is **HTTP 200**, success. Otherwise, bad login.

  #{ExFTP.Doc.returns(success: "{:ok, authenticator_state}", failure: "{:error, bad_login}")}

  ### 💻 Examples

      iex> alias ExFTP.Auth.DigestAuth
      iex> username = "alice"
      iex> password = "password1234"
      iex> Application.put_env(:ex_ftp, :authenticator, ExFTP.Auth.DigestAuth)
      iex> Application.put_env(:ex_ftp, :authenticator_config, %{
      iex>  login_url: "https://httpbin.dev/digest-auth/auth/" <> username <> "/" <> password <> "/MD5",
      iex>  login_method: :get
      iex> })
      iex> {:ok, _} = DigestAuth.login(password , %{username: username})

  #{ExFTP.Doc.related(["`t:ExFTP.Auth.DigestAuthConfig.t/0`", "`t:ExFTP.Auth.Common.login_url/0`", "`t:ExFTP.Auth.Common.login_method/0`"])}


  <!-- tabs-close -->
  """
  @impl Authenticator
  @spec login(
          password :: Authenticator.password(),
          authenticator_state :: Authenticator.authenticator_state()
        ) :: {:ok, Authenticator.authenticator_state()} | {:error, term()}
  def login(password, authenticator_state) do
    with {:ok, config} <- validate_config(DigestAuthConfig) do
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
      * Calls the **authenticated_url** - receives **HTTP 401** with digest headers
      * Performs calculation, calls **authenticated_url** with proper headers
      * If the response is **HTTP 200**, success. Otherwise, bad login.
   * If the config does not have **authenticated_url**,
     * investigate the **authenticator_state** for `authenticated: true`

  #{ExFTP.Doc.returns(success: "`true` or `false`")}

  ### 💻 Examples

      iex> alias ExFTP.Auth.DigestAuth
      iex> username = "alice"
      iex> password = "password1234"
      iex> Application.put_env(:ex_ftp, :authenticator, ExFTP.Auth.DigestAuth)
      iex> Application.put_env(:ex_ftp, :authenticator_config, %{
      iex>  login_url: "https://httpbin.dev/digest-auth/auth/" <> username <> "/" <> password <> "/MD5",
      iex>  authenticated_url: "https://httpbin.dev/digest-auth/auth/" <> username <> "/" <> password <> "/MD5",
      iex>  authenticated_method: :get,
      iex> })
      iex> DigestAuth.authenticated?(%{username: username, password: password})
      true

  #{ExFTP.Doc.related(["`t:ExFTP.Auth.DigestAuthConfig.t/0`", "`t:ExFTP.Auth.Common.authenticated_url/0`", "`t:ExFTP.Auth.Common.authenticated_method/0`"])}

  <!-- tabs-close -->
  """
  @impl Authenticator
  @spec authenticated?(authenticator_state :: Authenticator.authenticator_state()) :: boolean()
  def authenticated?(authenticator_state) do
    with {:ok, config} <- validate_config(DigestAuthConfig) do
      check_authentication(config, authenticator_state)
    end
  end

  defp check_login(
         password,
         %{login_url: url, login_method: http_method} = _config,
         %{username: username} = authenticator_state
       ) do
    url
    |> ExFTP.DigestAuthUtil.request(http_method, username, password)
    |> case do
      {:ok, %{status: 200}} ->
        authenticator_state = Map.put(authenticator_state, :password, password)
        {:ok, authenticator_state}

      _ ->
        {:error, "Did not get a 200 response"}
    end
  end

  defp check_authentication(%{authenticated_url: nil} = _config, %{authenticated: true} = _authenticator_state),
    do: true

  defp check_authentication(
         %{authenticated_url: url, authenticated_method: http_method} = _config,
         %{username: username, password: password} = _authenticator_state
       )
       when not is_nil(url) do
    url
    |> ExFTP.DigestAuthUtil.request(http_method, username, password)
    |> case do
      {:ok, %{status: 200}} ->
        true

      _ ->
        false
    end
  end

  defp check_authentication(_config, _authenticator_state), do: false
end
