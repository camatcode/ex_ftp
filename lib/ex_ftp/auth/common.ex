defmodule ExFTP.Auth.Common do
  @moduledoc false

  def validate_config(mod) do
    with {:ok, config} <- get_authenticator_config() do
      validated = mod.build(config)
      {:ok, validated}
    end
  end

  def get_key(map, k) when is_map(map) do
    Map.get(map, k)
    |> case do
      nil -> {:error, "No #{k} found"}
      v -> {:ok, v}
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
