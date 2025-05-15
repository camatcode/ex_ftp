# SPDX-License-Identifier: Apache-2.0
defmodule ExFTP.Auth.DigestAuth do
  @moduledoc """
  An implementation of `ExFTP.Authenticator` which will call out to an endpoint with HTTP auth digest to determine access

  This route at minimum, assumes there exists an HTTP endpoint that when called with HTTP auth digest
    that it will respond HTTP *200* if successful; any other response is considered a bad login.

  Additionally, this authenticator can be set up to reach out to another endpoint that when called with HTTP auth digest
   will respond status *200* if the user is still considered authenticated, and any other status if
   the user should not be considered authenticated.

  Independently, this authenticator can set a time-to-live (TTL) which, after reached, will require re-auth check from
  a user.

  <!-- tabs-open -->

  ### ⚙️ Configuration

  *Keys*

  * **authenticator**  == `ExFTP.Auth.DigestAuth`
  * **authenticator_config** :: `t:ExFTP.Auth.DigestAuthConfig.t/0`

  *Example*

  ```elixir
    %{
      authenticator: ExFTP.Auth.DigestAuth,
      authenticator_config: %{
        login_url: "https://httpbin.dev/digest-auth/",
        login_method: :get,
        authenticated_url: "https://httpbin.dev/hidden-basic-auth/",
        authenticated_method: :get,
        authenticated_ttl_ms: 1000 * 60
      }
    }
  ```

  #{ExFTP.Doc.related(["`ExFTP.Authenticator`"])}

  #{ExFTP.Doc.resources("section-4")}

  <!-- tabs-close -->
  """

  import ExFTP.Auth.Common
  alias ExFTP.Auth.DigestAuthConfig
  alias ExFTP.Authenticator

  @behaviour Authenticator

  @doc """
  Always returns `true`.

  > #### No performance benefit {: .tip}
  > This method is normally used to short-circuit login requests.
  > The performance gain in that short-circuit is negligible for this auth, so it's not used.
  """
  @impl Authenticator
  @spec valid_user?(username :: Authenticator.username()) :: boolean
  def valid_user?(_username), do: true

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

  @impl Authenticator
  @spec authenticated?(authenticator_state :: Authenticator.authenticator_state()) :: boolean()
  def authenticated?(authenticator_state) do
    with {:ok, config} <- validate_config(DigestAuthConfig) do
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
    ExFTP.DigestAuthUtil.request(url, http_method, username, password)
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
    ExFTP.DigestAuthUtil.request(url, http_method, username, password)
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
