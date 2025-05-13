# SPDX-License-Identifier: Apache-2.0
defmodule ExFTP.Auth.BearerAuth do
  @moduledoc false

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

  defp check_authentication(_config, authenticator_state) do
    IO.inspect(authenticator_state, label: :state)
    {:error, "Not Authenticated"}
  end
end
