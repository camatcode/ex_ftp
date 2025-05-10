defmodule FTP2Cloud.Auth.PassthroughAuth do
  @moduledoc false
  @behaviour FTP2Cloud.Authenticator

  alias FTP2Cloud.Authenticator

  @impl Authenticator
  def valid_user?("root"), do: false
  def valid_user?(_username), do: true

  @impl Authenticator
  def login(_password, %{username: "root"}), do: {:error, %{}}
  def login(_password, %{username: username} = auth_state), do: {:ok, auth_state}
  def login(_p, _), do: {:error, %{}}

  @impl Authenticator
  def authenticated?(%{authenticated: authenticated} = _state), do: authenticated
  def authenticated?(_), do: false
end
