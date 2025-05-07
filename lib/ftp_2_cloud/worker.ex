defmodule FTP2Cloud.Worker do
  @moduledoc false

  use GenServer

  import FTP2Cloud.Common

  require Logger

  def child_spec(arg) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [arg]},
      restart: :temporary
    }
  end

  def start_link(socket) do
    GenServer.start_link(__MODULE__, socket)
  end

  def init(socket) do
    {:ok, host} =
      System.get_env("FTP_ADDR", "127.0.0.1")
      |> to_charlist()
      |> :inet.parse_address()

    unless Application.get_env(:ftp_2_cloud, :mix_env) == :test do
      {:ok, {ip_address, _port}} = :inet.peername(socket)
      ip_address_str = ip_address |> Tuple.to_list() |> Enum.join(".")
      Logger.info("Received FTP connection from #{ip_address_str}")
    end

    connector =
      Application.get_env(:ftp_2_cloud, :storage_connector, FTP2Cloud.Connectors.FileConnector)

    authenticator =
      Application.get_env(:ftp_2_cloud, :authenticator, FTP2Cloud.Auth.PassthroughAuth)

    send_resp(220, "Hello from FTP2Cloud.", socket)

    {:ok,
     %{
       host: host,
       socket: socket,
       pasv_socket: nil,
       type: :ascii,
       username: nil,
       current_user: nil,
       user_prefix: nil,
       prefix: "/",
       virtual_directories: [],
       storage_connector: connector,
       authenticator: authenticator
     }}
  end

  def handle_info({:tcp, _socket, data}, state) do
    sanitized =
      if String.starts_with?(inspect(data), "\"PASS") do
        "PASS *******\r\n"
      else
        inspect(data)
      end

    Logger.info("Received FTP message:\t#{inspect(sanitized)}")

    data
    |> parse()
    |> run(state)
  end

  def handle_info(:read_complete, %{socket: socket, pasv_socket: pasv} = state) do
    :ok = send_resp(226, "Transfer Complete.", socket)

    FTP2Cloud.PassiveSocket.close(pasv)
    {:noreply, %{state | pasv_socket: nil}}
  end

  def handle_info({:tcp_closed, _}, state), do: {:stop, :normal, state}
  def handle_info({:tcp_error, _}, state), do: {:stop, :normal, state}

  def parse(data) do
    data
    |> String.trim()
    |> String.split(" ", parts: 2)
  end

  def run(["QUIT"], state) do
    quit(state)
  end

  def run(["SYST"], %{socket: socket} = state) do
    :ok = send_resp(215, "UNIX Type: L8", socket)
    {:noreply, state}
  end

  def run(["TYPE", type], %{socket: socket} = state) do
    case type do
      "I" ->
        send_resp(200, "Switching to binary mode.", socket)
        {:noreply, %{state | type: :image}}

      "A" ->
        send_resp(200, "Switching to ASCII mode.", socket)
        {:noreply, %{state | type: :ascii}}

      _ ->
        send_resp(504, "Unsupported transfer type.", socket)
        {:noreply, state}
    end
  end

  # Auth Commands

  def run(["USER", username], %{socket: _socket} = state) do
    :ok = state.authenticator.user(username, state)
    {:noreply, %{state | username: username}}
  end

  def run(["PASS", password], %{socket: _socket} = state) do
    :ok = state.authenticator.pass(password, state)
    {:noreply, state}
  end

  # Storage Connector Commands
  def run(["PWD"], %{socket: socket} = state) do
    :ok = send_resp(257, "\"#{state.prefix}\" is the current directory", socket)
    {:noreply, state}
  end

  def run(_, %{socket: socket} = state) do
    :ok = send_resp(502, "Command not implemented.", socket)
    {:noreply, state}
  end
end
