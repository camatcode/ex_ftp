defmodule FTP2Cloud.Worker do
  @moduledoc false

  use GenServer

  import FTP2Cloud.Common

  alias FTP2Cloud.PassiveSocket

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
      Application.get_env(:ftp_2_cloud, :storage_connector, FTP2Cloud.Connector.FileConnector)

    authenticator =
      Application.get_env(:ftp_2_cloud, :authenticator, FTP2Cloud.Auth.PassthroughAuth)

    server_name = Application.get_env(:ftp_2_cloud, :server_name, FTP2Cloud)

    send_resp(220, "Hello from #{server_name}.", socket)

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
       connector_state: %{current_working_directory: "/"},
       authenticator: authenticator,
       authenticator_state: %{}
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

    PassiveSocket.close(pasv)
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

  def run(["PASV"], %{socket: socket} = server_state) do
    if server_state.authenticator.authenticated?(server_state.authenticator_state) do
      {:ok, pasv} = PassiveSocket.start_link()

      host = Map.get(server_state, :host)
      {:ok, port} = PassiveSocket.get_port(pasv)
      pasv_string = ip_port_to_pasv(host, port)

      :ok = send_resp(227, "Entering Passive Mode (#{pasv_string}).", socket)
      {:noreply, %{server_state | pasv_socket: pasv}}
    else
      :ok =
        send_resp(
          530,
          "Authentication failed.",
          socket
        )

      {:noreply, server_state}
    end
  end

  # Auth Commands

  def run(["USER", username], %{socket: socket} = server_state) do
    {:ok, authenticator_state} =
      server_state.authenticator.user(username, socket, server_state.authenticator_state)

    new_state = server_state |> Map.put(:authenticator_state, authenticator_state)

    {:noreply, new_state}
  end

  def run(["PASS", password], %{socket: socket} = server_state) do
    {:ok, authenticator_state} =
      server_state.authenticator.pass(password, socket, server_state.authenticator_state)

    new_state = server_state |> Map.put(:authenticator_state, authenticator_state)

    {:noreply, new_state}
  end

  # Storage Connector Commands
  def run(["PWD"], %{socket: socket} = server_state) do
    {:ok, connector_state} =
      server_state.storage_connector.pwd(
        socket,
        server_state.connector_state,
        server_state.authenticator,
        server_state.authenticator_state
      )

    new_state = server_state |> Map.put(:connector_state, connector_state)

    {:noreply, new_state}
  end

  def run(["CDUP"], state) do
    run(["CWD", ".."], state)
  end

  def run(["CWD", path], %{socket: socket} = server_state) do
    {:ok, connector_state} =
      server_state.storage_connector.cwd(
        path,
        socket,
        server_state.connector_state,
        server_state.authenticator,
        server_state.authenticator_state
      )

    new_state = server_state |> Map.put(:connector_state, connector_state)

    {:noreply, new_state}
  end

  def run(["MKD", path], %{socket: socket} = server_state) do
    {:ok, connector_state} =
      server_state.storage_connector.mkd(
        path,
        socket,
        server_state.connector_state,
        server_state.authenticator,
        server_state.authenticator_state
      )

    new_state = server_state |> Map.put(:connector_state, connector_state)

    {:noreply, new_state}
  end

  def run(["RMD", path], %{socket: socket} = server_state) do
    {:ok, connector_state} =
      server_state.storage_connector.rmd(
        path,
        socket,
        server_state.connector_state,
        server_state.authenticator,
        server_state.authenticator_state
      )

    new_state = server_state |> Map.put(:connector_state, connector_state)

    {:noreply, new_state}
  end

  def run(["LIST", "-a"], %{socket: socket} = server_state) do
    with {:ok, pasv} <- with_pasv_socket(server_state) do
      {:ok, connector_state} =
        server_state.storage_connector.list_a(
          socket,
          pasv,
          server_state.connector_state,
          server_state.authenticator,
          server_state.authenticator_state
        )

      new_state = server_state |> Map.put(:connector_state, connector_state)

      {:noreply, new_state}
    end
  end

  def run(_, %{socket: socket} = state) do
    :ok = send_resp(502, "Command not implemented.", socket)
    {:noreply, state}
  end
end
