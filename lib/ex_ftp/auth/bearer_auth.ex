# SPDX-License-Identifier: Apache-2.0
defmodule ExFTP.Auth.BearerAuth do
  @moduledoc """
  An implementation of `ExFTP.Authenticator` which will call out to an endpoint with a Bearer token to determine access

  This route at minimum, assumes there exists an HTTP endpoint that when called with "authorization" : "Bearer {provided_bearer}"
    in the headers that it will respond HTTP *200* if successful; any other response is considered a bad login.

  Additionally, this authenticator can be set up to reach out to another endpoint that when called with a Bearer token
   in the headers will respond status *200* if the user is still considered authenticated, and any other status if
   the user should not be considered authenticated.

  Independently, this authenticator can set a time-to-live (TTL) which, after reached, will require re-auth check from
  a user.

  <!-- tabs-open -->

  ### ⚙️ Configuration

  *Keys*

  * **authenticator**  == `ExFTP.Auth.BearerAuth`
  * **authenticator_config** :: `t:ExFTP.Auth.BearerAuthConfig.t/0`

  *Example*

  ```elixir
    %{
      authenticator: ExFTP.Auth.BearerAuth,
      authenticator_config: %{
        login_url: "https://httpbin.dev/bearer",
        login_method: :post,
        authenticated_url: "https://httpbin.dev/bearer",
        authenticated_method: :post,
        authenticated_ttl_ms: 1000 * 60
      }
    }
  ```

  #{ExFTP.Doc.related(["`ExFTP.Authenticator`"])}

  #{ExFTP.Doc.resources("section-4")}

  <!-- tabs-close -->
  """

  import ExFTP.Auth.Common

  alias ExFTP.Auth.BearerAuthConfig
  alias ExFTP.Auth.WebhookAuth
  alias ExFTP.Authenticator
  @behaviour Authenticator

  @doc """
  Always returns `true`.

  > #### No performance benefit {: .tip}
  > This method is normally used to short-circuit login requests.
  > The performance gain in that short-circuit is negligible for this authenticator, so it's not used.
  """
  @impl Authenticator
  @spec valid_user?(username :: ExFTP.Authenticator.username()) :: boolean
  def valid_user?(username), do: WebhookAuth.valid_user?(username)

  @doc """
  Requests a login using a Bearer token.

  <!-- tabs-open -->

  ### 🏷️ Params
    * **password** :: `t:ExFTP.Authenticator.password/0`
    * **authenticator_state** :: `t:ExFTP.Authenticator.authenticator_state/0`

  ### 🧑‍🍳 Workflow

   * Reads the `authenticator_config`.
   * Receives a bearer token from the client
   * Calls the `login_url` with the proper bearer token headers (e.g `http://httpbin.dev/bearer`)
   * If the response is HTTP 200, success. Otherwise, bad login.

  #{ExFTP.Doc.returns(success: "{:ok, authenticator_state}", failure: "{:error, bad_login}")}

  ### 💻 Examples

      iex> alias ExFTP.Auth.BearerAuth
      iex> Application.put_env(:ex_ftp, :authenticator, ExFTP.Auth.BearerAuth)
      iex> Application.put_env(:ex_ftp, :authenticator_config, %{
      iex>  login_url: "https://httpbin.dev/bearer",
      iex>  login_method: :post
      iex> })
      iex> {:ok, _} = BearerAuth.login("my.bearer.token" , %{})


  ### ⚠️ Reminders
  > #### Authenticator State {: .tip}
  >
  > The `t:ExFTP.Authenticator.authenticator_state/0` will contain a `:username` key, if one was provided.
  >
  > On success, the **authenticator_state** will be automatically updated to include `authenticated: true`.
  > See `authenticated?/1` for more information.

  #{ExFTP.Doc.related(["`t:ExFTP.Auth.WebhookAuthConfig.t/0`", "`t:ExFTP.Auth.Common.login_url/0`", "`t:ExFTP.Auth.Common.login_method/0`", "`t:ExFTP.Auth.WebhookAuthConfig.password_hash_type/0`"])}

  #{ExFTP.Doc.resources("section-4")}

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

   * Reads the `authenticator_config`.
   * If the config has `authenticated_url`,
     * Calls it with a bearer token provided by the user in the headers (e.g `http://httpbin.dev/bearer`)
     * If the response is HTTP 200, success. Otherwise, no longer authenticated.
   * If the config does not have `authenticated_url`,
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

  #{ExFTP.Doc.resources("section-4")}

  <!-- tabs-close -->
  """
  @impl Authenticator
  @spec authenticated?(authenticator_state :: Authenticator.authenticator_state()) :: boolean()
  def authenticated?(authenticator_state) do
    with {:ok, config} <- validate_config(BearerAuthConfig) do
      check_authentication(config, authenticator_state)
    end
    |> case do
      {:ok, _} -> true
      _ -> false
    end
  end

  defp check_login(
         provided_token,
         %{login_url: url, login_method: http_method} = _config,
         authenticator_state
       ) do
    headers = [{"authorization", "Bearer #{provided_token}"}]

    Req.request(url: url, method: http_method, redirect: true, headers: headers)
    |> case do
      {:ok, %{status: 200}} ->
        {:ok, Map.put(authenticator_state, :bearer_token, provided_token)}

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
         %{bearer_token: bearer_token} = authenticator_state
       )
       when not is_nil(url) and not is_nil(bearer_token) do
    headers = [{"authorization", "Bearer #{bearer_token}"}]

    Req.request(url: url, method: http_method, redirect: true, headers: headers)
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
