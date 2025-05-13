# SPDX-License-Identifier: Apache-2.0
defmodule ExFTP.Auth.BearerAuth do
  @moduledoc false

  import ExFTP.Auth.Common

  alias ExFTP.Authenticator
  @behaviour Authenticator

  @impl Authenticator
  @spec valid_user?(username :: ExFTP.Authenticator.username()) :: boolean
  def valid_user?(_username), do: true

  @impl Authenticator
  @spec login(
          password :: Authenticator.password(),
          authenticator_state :: Authenticator.authenticator_state()
        ) :: {:ok, Authenticator.authenticator_state()} | {:error, term()}
  def login(_password, authenticator_state),
    do: {:ok, authenticator_state}

  @impl Authenticator
  @spec authenticated?(authenticator_state :: Authenticator.authenticator_state()) :: boolean()
  def authenticated?(_authenticator_state), do: true
end
