# SPDX-License-Identifier: Apache-2.0
defmodule ExFTP.Application do
  @moduledoc false

  use Application

  require Logger

  @impl true
  def start(_type, _args) do
    port = Application.get_env(:ex_ftp, :ftp_port, 4041)

    children = [
      {Cachex, [:auth_cache]},
      {ThousandIsland, port: port, handler_module: ExFTP.Worker, transport_options: [packet: :line]}
    ]

    opts = [strategy: :one_for_one, name: ExFTP.Supervisor]
    Logger.info("Accepting connections on port #{port}")
    Supervisor.start_link(children, opts)
  end
end
