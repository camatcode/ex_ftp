defmodule ExFTP.Authenticator do
  @moduledoc false

  @type authenticator_state :: %{}

  @type username :: String.t()
  @type password :: String.t()

  @callback valid_user?(username) :: boolean()
  @callback login(password, authenticator_state) ::
              {:ok, authenticator_state()} | {:error, term()}
  @callback authenticated?(authenticator_state) :: boolean()
end
