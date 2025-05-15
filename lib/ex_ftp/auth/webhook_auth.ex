# SPDX-License-Identifier: Apache-2.0
defmodule ExFTP.Auth.WebhookAuth do
  @moduledoc """
  An implementation of `ExFTP.Authenticator` which will call out to an HTTP endpoint to determine access

  This route at minimum, assumes there exists an HTTP endpoint that when called with `username` and `password_hash`
  as query parameters will respond status *200* on a valid parameters and any other status on an invalid login.

  Additionally, this authenticator can be set up to reach out to another endpoint that when called with a `username`
  query parameter will respond status *200* if the user is still considered authenticated, and any other status if
  the user should not be considered authenticated.

  Independently, this authenticator can set a time-to-live (TTL) which, after reached, will require re-auth check from
  a user.

  <!-- tabs-open -->

  ### ⚙️ Configuration

  *Keys*

  * **authenticator**  == `ExFTP.Auth.WebhookAuth`
  * **authenticator_config** :: `t:ExFTP.Auth.WebhookAuthConfig.t/0`

  *Example*

  ```elixir
    %{
      authenticator: ExFTP.Auth.WebhookAuth,
      authenticator_config: %{
        login_url: "https://httpbin.dev/status/200",
        login_method: :post,
        password_hash_type: :sha256,
        authenticated_url: "https://httpbin.dev/status/200",
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

  alias ExFTP.Auth.WebhookAuthConfig
  alias ExFTP.Authenticator

  @behaviour Authenticator

  @doc """
  Always returns `true`.

  > #### No performance benefit {: .tip}
  > This method is normally used to short-circuit login requests.
  > The performance gain in that short-circuit is negligible for webhooks, so it's not used.
  """
  @impl Authenticator
  @spec valid_user?(username :: Authenticator.username()) :: boolean
  def valid_user?(_username), do: true

  @doc """
  Requests a login using a callback.

  <!-- tabs-open -->

  ### 🏷️ Params
    * **password** :: `t:ExFTP.Authenticator.password/0`
    * **authenticator_state** :: `t:ExFTP.Authenticator.authenticator_state/0`

  ### 🧑‍🍳 Workflow

   * Reads the `authenticator_config`.
   * Receives a password from the client (a `:username` key might exist in the **authenticator_state**)
   * Hashes the password
   * Calls the `login_url` (e.g `http://httpbin.dev/get?username={username}&password_hash={password_hash}`)
   * If the response is HTTP 200, success. Otherwise, bad login.

  #{ExFTP.Doc.returns(success: "{:ok, authenticator_state}", failure: "{:error, bad_login}")}

  ### 💻 Examples

      iex> alias ExFTP.Auth.WebhookAuth
      iex> Application.put_env(:ex_ftp, :authenticator, ExFTP.Auth.WebhookAuth)
      iex> Application.put_env(:ex_ftp, :authenticator_config, %{
      iex>  login_url: "https://httpbin.dev/status/200",
      iex>  login_method: :post,
      iex>  password_hash_type: :sha256
      iex> })
      iex> {:ok, _} = WebhookAuth.login("password123", %{username: "jsmith"})


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
          password :: Authenticator.password(),
          authenticator_state :: Authenticator.authenticator_state()
        ) :: {:ok, Authenticator.authenticator_state()} | {:error, term()}
  def login(password, authenticator_state) do
    with {:ok, config} <- validate_config(WebhookAuthConfig) do
      check_login(password, config, authenticator_state)
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
     * Calls it (e.g `http://httpbin.dev/get?username={username}`)
     * If the response is HTTP 200, success. Otherwise, no longer authenticated.
   * If the config does not have `authenticated_url`,
     * investigate the **authenticator_state** for `authenticated: true`

  #{ExFTP.Doc.returns(success: "`true` or `false`")}

  ### 💻 Examples

      iex> alias ExFTP.Auth.WebhookAuth
      iex> Application.put_env(:ex_ftp, :authenticator, ExFTP.Auth.WebhookAuth)
      iex> Application.put_env(:ex_ftp, :authenticator_config, %{
      iex>  login_url: "https://httpbin.dev/status/200",
      iex>  authenticated_url: "https://httpbin.dev/get",
      iex>  authenticated_method: :get,
      iex> })
      iex> WebhookAuth.authenticated?(%{username: "jsmith"})
      true

  #{ExFTP.Doc.related(["`t:ExFTP.Auth.WebhookAuthConfig.t/0`", "`t:ExFTP.Auth.Common.authenticated_url/0`", "`t:ExFTP.Auth.Common.authenticated_method/0`"])}

  #{ExFTP.Doc.resources("section-4")}

  <!-- tabs-close -->
  """
  @impl Authenticator
  def authenticated?(authenticator_state) do
    with {:ok, config} <- validate_config(WebhookAuthConfig) do
      check_authentication(config, authenticator_state)
    end
    |> case do
      {:ok, _} -> true
      _ -> false
    end
  end

  defp check_login(
         password,
         %{login_url: url, login_method: http_method} = config,
         authenticator_state
       ) do
    params =
      if authenticator_state[:username], do: [username: authenticator_state[:username]], else: []

    params = params ++ [password_hash: hash_password(password, config)]

    Req.request(url: url, method: http_method, redirect: true, params: params)
    |> case do
      {:ok, %{status: 200}} ->
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

  defp check_authentication(%{authenticated_url: nil} = _config, _authenticator_state) do
    {:error, "Not Authenticated"}
  end

  defp check_authentication(
         %{authenticated_url: url, authenticated_method: http_method} = _config,
         authenticator_state
       ) do
    params =
      if authenticator_state[:username], do: [username: authenticator_state[:username]], else: []

    Req.request(url: url, method: http_method, redirect: true, params: params)
    |> case do
      {:ok, %{status: 200}} ->
        {:ok, authenticator_state}

      _ ->
        {:error, "Did not get a 200 response"}
    end
  end

  defp hash_password(password, %{password_hash_type: password_hash_type}) do
    :crypto.hash(password_hash_type, password)
    |> Base.encode16(case: :lower)
  end
end
