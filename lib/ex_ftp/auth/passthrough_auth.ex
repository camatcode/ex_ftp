defmodule ExFTP.Auth.PassthroughAuth do
  @moduledoc """
  An implementation of `ExFTP.Authenticator` which permits any user except `"root"`
  """
  alias ExFTP.Authenticator
  @behaviour Authenticator

  @impl Authenticator
  @doc """
  If the username is `"root"`, this function will return `false`, otherwise `true`

  See: `c:ExFTP.Authenticator.valid_user?/1`
  """
  def valid_user?("root"), do: false
  def valid_user?(_username), do: true

  @impl Authenticator
  @doc """
  Login will respond `{:ok, unmodified_auth_state}` to anyone but `username: "root"`

  See: `c:ExFTP.Authenticator.login/2`
  """
  def login(_password, %{username: "root"}), do: {:error, %{}}
  def login(_password, %{username: _username} = auth_state), do: {:ok, auth_state}
  def login(_p, _), do: {:error, %{}}

  @impl Authenticator
  @doc """
  This function assumes the user is still authenticated as long as `authenticated: true`
    still exists in its `authenticator_state`.

  That key is placed or removed by `ExFTP.Worker` on login attempts.

  See: `c:ExFTP.Authenticator.authenticated?/1`
  """
  def authenticated?(%{authenticated: authenticated} = _state), do: authenticated
  def authenticated?(_), do: false
end
