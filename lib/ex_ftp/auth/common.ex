# SPDX-License-Identifier: Apache-2.0
defmodule ExFTP.Auth.Common do
  @moduledoc """
  A module describing types functions common across all `ExFTP.Authenticator`
  """

  @typedoc """
  A URL used to check if a user should still be considered authenticated

  <!-- tabs-open -->

  #{ExFTP.Doc.related(["`c:ExFTP.Authenticator.authenticated?/1`"])}

  <!-- tabs-close -->
  """
  @type authenticated_url :: URI.t() | String.t()

  @typedoc """
  Paired with `t:authenticated_url/0`

  <!-- tabs-open -->

  #{ExFTP.Doc.related(["`c:ExFTP.Authenticator.authenticated?/1`"])}

  <!-- tabs-close -->
  """
  @type authenticated_method :: http_method()

  @typedoc """
  How many milliseconds pass before a user's session is not assumed still-authenticated.

  <!-- tabs-open -->

  #{ExFTP.Doc.related(["`c:ExFTP.Authenticator.authenticated?/1`"])}

  <!-- tabs-close -->
  """
  @type authenticated_ttl_ms :: integer()

  @typedoc """
  A URL used to log in a user

  <!-- tabs-open -->

  #{ExFTP.Doc.related(["`c:ExFTP.Authenticator.login/2`"])}

  <!-- tabs-close -->
  """
  @type login_url :: URI.t() | String.t()

  @typedoc """
  Paired with `t:login_url/0`

  <!-- tabs-open -->

  #{ExFTP.Doc.related(["`c:ExFTP.Authenticator.login/2`"])}

  <!-- tabs-close -->
  """
  @type login_method :: http_method()

  @typedoc """
  An HTTP method to use in a request.

  <!-- tabs-open -->

  #{ExFTP.Doc.related(["`c:ExFTP.Authenticator.authenticated?/1`", "`c:ExFTP.Authenticator.login/2`"])}

  <!-- tabs-close -->
  """
  @type http_method ::
          :get | :head | :post | :put | :connect | :delete | :options | :trace | :patch

  def validate_config(mod) do
    with {:ok, config} <- get_authenticator_config() do
      validated = mod.build(config)
      {:ok, validated}
    end
  end

  def prepare(m) do
    m
    |> prepare_values()
    |> prepare_keys()
  end

  def prepare_values(m) do
    m
  end

  def prepare_keys(m) do
    m
    |> snake_case_keys()
    |> atomize_keys()
  end

  def snake_case_keys(m) do
    m
    |> Enum.map(fn {key, val} ->
      {ProperCase.snake_case(key), val}
    end)
  end

  def atomize_keys(m) do
    m
    |> Enum.map(fn {key, val} ->
      key = String.to_atom(key)
      {key, val}
    end)
  end

  defp get_authenticator_config do
    Application.get_env(:ex_ftp, :authenticator_config)
    |> case do
      nil -> {:error, "No :authenticator_config found"}
      config -> {:ok, config}
    end
  end
end
