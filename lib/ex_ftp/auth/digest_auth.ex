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
  alias ExFTP.Authenticator
  alias ExFTP.Auth.DigestAuthConfig

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
    Req.request(
      url: url,
      method: http_method,
      redirect: true
    )
    |> case do
      {:ok, %{headers: %{"www-authenticate" => [digest_info]}}} ->
        with {:ok,
              %{
                opaque: opaque,
                nonce: nonce,
                realm: realm
              }} <- parse_digest(digest_info) do
          # Hash1=MD5(username:realm:password)
          hash_1 =
            :crypto.hash(:md5, "#{username}:#{realm}:#{password}")
            |> Base.encode16(case: :lower)

          # Hash2=MD5(method:digestURI)
          hash_2 =
            :crypto.hash(:md5, "#{http_method |> Atom.to_string() |> String.upcase()}:#{"/"}")
            |> Base.encode16(case: :lower)

          response =
            :md5
            |> :crypto.hash(Enum.join([hash_1, nonce, hash_2], ":"))
            |> Base.encode16(case: :lower)
            |> IO.inspect(label: :response)

          # "Digest username=\"#{username}\", realm=\"#{realm}\", uri=\"#{uri}\", qop=\"auth\", nc=00000001, "

          Req.request(
            url: url,
            method: http_method,
            redirect: true,
            auth: response
          )
          |> IO.inspect(label: :req_2)
        end

      _ ->
        {:error, "No digest info returned from url"}
    end

    {:ok, authenticator_state}
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
      redirect: true
    )
    |> case do
      {:ok, %{headers: %{"www-authenticate" => [digest_info]}}} ->
        with {:ok,
              %{
                opaque: opaque,
                nonce: nonce,
                realm: realm
              }} <- parse_digest(digest_info) do
          # Hash1=MD5(username:realm:password)
          hash_1 =
            :crypto.hash(:md5, "#{username}:#{realm}:#{password}")
            |> Base.encode16(case: :lower)

          # Hash2=MD5(method:digestURI)
          hash_2 =
            :crypto.hash(:md5, "#{http_method |> Atom.to_string() |> String.upcase()}:#{"/"}")
            |> Base.encode16(case: :lower)

          response =
            :md5
            |> :crypto.hash(Enum.join([hash_1, nonce, hash_2], ":"))
            |> Base.encode16(case: :lower)
            |> IO.inspect(label: :response)

          Req.request(
            url: url,
            method: http_method,
            redirect: true,
            auth: response
          )
          |> IO.inspect(label: :req_2)
        end
        |> IO.inspect(label: :after_with)

      _ ->
        {:error, "No digest info returned from url"}
    end

    {:ok, authenticator_state}
  end

  def parse_digest(digest_info, opts \\ []) do
    opts = Keyword.merge([algorithm: :md5, qop: :auth], opts)

    try do
      parsed =
        digest_info
        |> String.split(", ")
        |> Enum.map(fn part ->
          [k, v] =
            String.replace(part, "Digest ", "")
            |> String.replace("\"", "")
            |> String.split("=", parts: 2)

          {String.to_atom(k), v}
        end)
        |> Enum.map(&serialize/1)
        |> Map.new()

      qop = opts[:qop]
      algo = opts[:algorithm]

      parsed
      |> case do
        %{qop: ^qop, algorithm: ^algo} ->
          {:ok, parsed}

        _ ->
          {:error, "Does not match requirements"}
      end
    rescue
      e -> {:error, e |> IO.inspect(label: :e)}
    end
  end

  defp serialize({:algorithm, v}), do: {:algorithm, v |> String.downcase() |> String.to_atom()}
  defp serialize({:qop, v}), do: {:qop, String.to_atom(v)}
  defp serialize({k, v}), do: {k, v}

  defp check_authentication(_config, _authenticator_state) do
    {:error, "Not Authenticated"}
  end
end
