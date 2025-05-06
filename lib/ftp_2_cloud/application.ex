defmodule FTP2Cloud.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    port = Application.get_env(:ftp_2_cloud, :ftp_port)

    children = [
      {DynamicSupervisor, name: FTP2Cloud.WorkerSupervisor, strategy: :one_for_one},
      {FTP2Cloud.Server, port: port}
    ]

    opts = [strategy: :one_for_one, name: FTP2Cloud.Supervisor]

    Supervisor.start_link(children, opts)
  end
end
