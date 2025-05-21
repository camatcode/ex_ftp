# SPDX-License-Identifier: Apache-2.0
defmodule ExFTP.Auth.BearerAuth do
  @moduledoc """
  When **authenticator** is `ExFTP.Auth.BearerAuth`, this authenticator will call out to an HTTP endpoint that
  implements [Bearer Tokens](https://swagger.io/docs/specification/v3_0/authentication/bearer-authentication/){:target=\"_blank\"}
  with the user's supplied credentials.

  <!-- tabs-open -->

  ### ⚙️ Configuration

  *Keys*

  * **authenticator**  == `ExFTP.Auth.BearerAuth`
  * **authenticator_config** :: `t:ExFTP.Auth.BearerAuthConfig.t/0`

  *Example*

  ```elixir
    %{
      # ... ,
      authenticator: ExFTP.Auth.BearerAuth,
      authenticator_config: %{
        login_url: "https://httpbin.dev/bearer",
        login_method: :post,
        authenticated_url: "https://httpbin.dev/bearer",
        authenticated_method: :post,
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

  alias ExFTP.Auth.BearerAuthConfig
  alias ExFTP.Auth.WebhookAuth
  alias ExFTP.Authenticator

  @doc """
  Always returns `true`.

  > #### No performance benefit {: .tip}
  > This method is normally used to short-circuit bad login requests.
  > The performance gain in that short-circuit is negligible for this authenticator, so it's not used.
  """
  @impl Authenticator
  @spec valid_user?(username :: ExFTP.Authenticator.username()) :: boolean
  def valid_user?(username), do: WebhookAuth.valid_user?(username)

  @doc """
  Requests a login using a
  [Bearer Token](https://swagger.io/docs/specification/v3_0/authentication/bearer-authentication/){:target=\"_blank\"}

  <!-- tabs-open -->

  ### 🏷️ Params
    * **password** :: `t:ExFTP.Authenticator.password/0`
    * **authenticator_state** :: `t:ExFTP.Authenticator.authenticator_state/0`

  ### 🧑‍🍳 Workflow

   * Reads the **authenticator_config**.
   * Receives a bearer token from the client (as a password)
   * Calls the **login_url** with the proper bearer token headers
   * If the response is **HTTP 200**, success. Otherwise, bad login.

  #{ExFTP.Doc.returns(success: "{:ok, authenticator_state}", failure: "{:error, bad_login}")}

  ### 💻 Examples

      iex> alias ExFTP.Auth.BearerAuth
      iex> Application.put_env(:ex_ftp, :authenticator, ExFTP.Auth.BearerAuth)
      iex> Application.put_env(:ex_ftp, :authenticator_config, %{
      iex>  login_url: "https://httpbin.dev/bearer",
      iex>  login_method: :post
      iex> })
      iex> {:ok, _} = BearerAuth.login("my.bearer.token" , %{})

  #{ExFTP.Doc.related(["`t:ExFTP.Auth.BearerAuthConfig.t/0`", "`t:ExFTP.Auth.Common.login_url/0`", "`t:ExFTP.Auth.Common.login_method/0`"])}

  <!-- tabs-close -->
  """
  @impl Authenticator
  @spec login(
          provided_token :: Authenticator.password(),
          authenticator_state :: Authenticator.authenticator_state()
        ) :: {:ok, Authenticator.authenticator_state()} | {:error, term()}
  def login(provided_token, authenticator_state) do
    with {:ok, config} <- validate_config(BearerAuthConfig) do
      check_login(provided_token, config, authenticator_state)
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
     * Calls it with a bearer token provided by the user in the headers
     * If the response is **HTTP 200**, success. Otherwise, no longer authenticated.
   * If the config does not have **authenticated_url**,
     * investigate the **authenticator_state** for `authenticated: true`

  #{ExFTP.Doc.returns(success: "`true` or `false`")}

  ### 💻 Examples

      iex> alias ExFTP.Auth.BearerAuth
      iex> Application.put_env(:ex_ftp, :authenticator, ExFTP.Auth.BearerAuth)
      iex> Application.put_env(:ex_ftp, :authenticator_config, %{
      iex>  login_url: "https://httpbin.dev/bearer",
      iex>  authenticated_url: "https://httpbin.dev/bearer",
      iex>  authenticated_method: :get,
      iex> })
      iex> BearerAuth.authenticated?(%{bearer_token: "my.bearer.token"})
      true

  #{ExFTP.Doc.related(["`t:ExFTP.Auth.BearerAuthConfig.t/0`", "`t:ExFTP.Auth.Common.authenticated_url/0`", "`t:ExFTP.Auth.Common.authenticated_method/0`"])}

  <!-- tabs-close -->
  """
  @impl Authenticator
  @spec authenticated?(authenticator_state :: Authenticator.authenticator_state()) :: boolean()
  def authenticated?(authenticator_state) do
    with {:ok, config} <- validate_config(BearerAuthConfig) do
      check_authentication(config, authenticator_state)
    end
  end

  defp check_login(provided_token, %{login_url: url, login_method: http_method} = _config, authenticator_state) do
    headers = [{"authorization", "Bearer #{provided_token}"}]

    [url: url, method: http_method, redirect: true, headers: headers]
    |> Req.request()
    |> case do
      {:ok, %{status: 200}} ->
        {:ok, Map.put(authenticator_state, :bearer_token, provided_token)}

      _ ->
        {:error, "Did not get a 200 response"}
    end
  end

  defp check_authentication(%{authenticated_url: nil} = _config, %{authenticated: true} = _authenticator_state),
    do: true

  defp check_authentication(
         %{authenticated_url: url, authenticated_method: http_method} = _config,
         %{bearer_token: bearer_token} = authenticator_state
       )
       when not is_nil(url) and not is_nil(bearer_token) do
    headers = [{"authorization", "Bearer #{bearer_token}"}]

    [url: url, method: http_method, redirect: true, headers: headers]
    |> Req.request()
    |> case do
      {:ok, %{status: 200}} ->
        true

      _ ->
        false
    end
  end

  defp check_authentication(_config, _authenticator_state), do: false
end
