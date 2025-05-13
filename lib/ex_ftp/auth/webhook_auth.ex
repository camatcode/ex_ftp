defmodule ExFTP.Auth.WebhookAuth do
  @moduledoc false

  import ExFTP.Auth.Common

  alias ExFTP.Authenticator
  @behaviour Authenticator

  @impl Authenticator
  @spec valid_user?(username :: Authenticator.username()) :: boolean
  def valid_user?(_username), do: true

  @impl Authenticator
  @spec login(
          password :: Authenticator.password(),
          authenticator_state :: Authenticator.authenticator_state()
        ) :: {:ok, Authenticator.authenticator_state()} | {:error, term()}
  def login(_password, authenticator_state) do
    with {:ok, config} <- get_authenticator_config(),
         {:ok, url} <- get_key(config, :login_url) do
      http_method = config[:login_method] || :get

      Req.request(url: url, method: http_method, redirect: true)
      |> case do
        {:ok, %{status: 200}} -> {:ok, authenticator_state}
        _ -> {:error, "Did not get a 200 response"}
      end
    end
  end

  @impl Authenticator
  def authenticated?(authenticator_state) do
    with {:ok, config} <- get_authenticator_config() do
      url = config[:authenticated_url]
      http_method = config[:authenticated_method] || :get

      if url do
        Req.request(url: url, method: http_method, redirect: true)
        |> case do
          {:ok, %{status: 200}} -> {:ok, authenticator_state}
          _ -> {:error, "Did not get a 200 response"}
        end
      else
        if authenticator_state[:authenticated] do
          {:ok, authenticator_state}
        else
          {:error, "Not authenticated"}
        end
      end
    end
  end
end
