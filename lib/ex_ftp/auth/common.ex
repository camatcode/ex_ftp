defmodule ExFTP.Auth.Common do
  @moduledoc false

  def get_authenticator_config do
    Application.get_env(:ex_ftp, :authenticator_config)
    |> case do
      nil -> {:error, "No :authenticator_config found"}
      config -> {:ok, config}
    end
  end

  def get_key(map, k) when is_map(map) do
    Map.get(map, k)
    |> case do
      nil -> {:error, "No #{k} found"}
      v -> {:ok, v}
    end
  end
end
