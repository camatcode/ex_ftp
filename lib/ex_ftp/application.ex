# SPDX-License-Identifier: Apache-2.0
defmodule ExFTP.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    port = Application.get_env(:ex_ftp, :ftp_port)

    children = [
      {Cachex, [:auth_cache]},
      {DynamicSupervisor, name: ExFTP.WorkerSupervisor, strategy: :one_for_one},
      {ExFTP.Server, port: port}
    ]

    opts = [strategy: :one_for_one, name: ExFTP.Supervisor]

    Supervisor.start_link(children, opts)
  end
end
