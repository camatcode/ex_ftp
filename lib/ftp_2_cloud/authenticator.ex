defmodule FTP2Cloud.Authenticator do
  @moduledoc false

  @type socket :: %{}
  @type authenticator_state :: %{}

  @type username :: String.t()
  @type password :: String.t()

  @callback user(username, socket, authenticator_state) ::
              {:ok, authenticator_state()} | {:error, term()}

  @callback pass(password, socket, authenticator_state) ::
              {:ok, authenticator_state()} | {:error, term()}

  @callback authenticated?(authenticator_state) :: boolean()
end
