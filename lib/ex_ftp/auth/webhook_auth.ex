defmodule ExFTP.Auth.WebhookAuth do
  @moduledoc """
  An implementation of `ExFTP.Authenticator` which will call out to an HTTP endpoint to determine access

  This route at minimum, assumes there exists an HTTP endpoint that when called with `username` and `password_hash`
  as query parameters will respond status *200* on a valid parameters and any other status on an invalid login.

  Additionally, this authenticator can be set up to reach out to another endpoint that when called with a `username`
  as query parameters will respond status *200* if the user is still considered authenticated, and any other status if
  the user should not be considered authenticated.

  Independently, this authenticator can set a time-to-live (TTL) which, after reached, will require re-auth from a user.

  <!-- tabs-open -->

  ### ⚙️ Configuration

  > #### Elixir {: .info}
  > This authenticator has several options to consider.
  >
  > ```elixir
  >     config :ex_ftp,
  >       ....
  >       authenticator: ExFTP.Auth.WebhookAuth,
  >       authenticator_config: %{
  >         login_url: "https://httpbin.org/get",
  >         login_method: :get,
  >         authenticated_url: "https://httpbin.org/post",
  >         authenticated_method: :post,
  >         authenticated_ttl_ms: 24 * 60 * 60 * 1000
  >       },
  >       ....
  > ```
  > ##### Required
  > * **authenticator** set to `ExFTP.Auth.WebhookAuth`.
  > * **authenticator_config** to exist.
  > * authenticator_config**.login_url** - the HTTP endpoint that will get called on a login attempt.
  > ##### Optional
  > * authenticator_config**.login_method** - the HTTP method that gets paired with the `login_url`
  > (e.g `:get` (default) or `:post`, etc.)
  > * authenticator_config**.authenticated_url** - the HTTP endpoint that will get called when the server
  > wants to ensure the session is still authenticated. If not defined, this authenticator tracks `authenticated: true` in
  > the **authenticator_state**
  > * authenticator_config**.authenticated_method** - the HTTP method that gets paired with the `authenticated_url`
  > (e.g `:get` (default) or `:post`, etc.)
  > * authenticator_config**.authenticated_ttl_ms** - How many milliseconds pass before the server will recheck that
  > a user is still authenticated within a single session (default: 1 day)

  #{ExFTP.Doc.related(["`ExFTP.Authenticator`"])}

  #{ExFTP.Doc.resources("section-4")}

  <!-- tabs-close -->
  """

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
