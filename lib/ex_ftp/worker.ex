defmodule ExFTP.Worker do
  @moduledoc false

  use GenServer

  import ExFTP.Common
  import ExFTP.Connector.Common

  alias ExFTP.PassiveSocket

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

    unless Application.get_env(:ex_ftp, :mix_env) == :test do
      {:ok, {ip_address, _port}} = :inet.peername(socket)
      ip_address_str = ip_address |> Tuple.to_list() |> Enum.join(".")
      Logger.info("Received FTP connection from #{ip_address_str}")
    end

    connector =
      Application.get_env(:ex_ftp, :storage_connector, ExFTP.Connector.FileConnector)

    authenticator =
      Application.get_env(:ex_ftp, :authenticator, ExFTP.Auth.PassthroughAuth)

    server_name = Application.get_env(:ex_ftp, :server_name, ExFTP)

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

  def handle_info(:read_complete, %{socket: _socket, pasv_socket: pasv} = state) do
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
    check_auth(server_state)
    |> case do
      :ok ->
        {:ok, pasv} = PassiveSocket.start_link()

        host = Map.get(server_state, :host)
        {:ok, port} = PassiveSocket.get_port(pasv)
        pasv_string = ip_port_to_pasv(host, port)

        :ok = send_resp(227, "Entering Passive Mode (#{pasv_string}).", socket)
        {:noreply, %{server_state | pasv_socket: pasv}}

      _ ->
        {:noreply, server_state}
    end
  end

  def run(["EPSV"], %{socket: socket} = server_state) do
    check_auth(server_state)
    |> case do
      :ok ->
        {:ok, pasv} = PassiveSocket.start_link()
        {:ok, port} = PassiveSocket.get_port(pasv)

        :ok = send_resp(229, "Entering Extended Passive Mode (|||#{port}|)", socket)
        {:noreply, %{server_state | pasv_socket: pasv}}

      _ ->
        {:noreply, server_state}
    end
  end

  def run(["EPRT", _eport_info], %{socket: socket} = server_state) do
    check_auth(server_state)
    |> case do
      :ok -> :ok = send_resp(200, "EPRT command successful.", socket)
      _ -> nil
    end

    {:noreply, server_state}
  end

  # Auth Commands

  def run(["USER", username], %{socket: socket, authenticator: authenticator} = server_state) do
    if authenticator.valid_user?(username) do
      :ok = send_resp(331, "User name okay, need password.", socket)

      Map.put(server_state, :authenticator_state, %{username: username})
      |> noreply()
    else
      # Yes I know, its strange - but I don't want to leak that this isn't a valid user to the client
      :ok = send_resp(331, "User name okay, need password.", socket)

      Map.put(server_state, :authenticator_state, %{})
      |> noreply()
    end
  end

  def run(
        ["PASS", password],
        %{socket: socket, authenticator: authenticator, authenticator_state: auth_state} =
          server_state
      ) do
    authenticator.login(password, auth_state)
    |> case do
      {:ok, auth_state} ->
        auth_state = auth_state |> Map.put(:authenticated, true)

        :ok = send_resp(230, "Welcome.", socket)

        Map.put(server_state, :authenticator_state, auth_state)
        |> noreply()

      {_, %{} = auth_state} ->
        :ok = send_resp(530, "Authentication failed.", socket)

        Map.put(server_state, :authenticator_state, auth_state)
        |> noreply()

      _ ->
        :ok = send_resp(530, "Authentication failed.", socket)

        server_state
        |> noreply()
    end
  end

  # Storage Connector Commands
  def run(["PWD"], %{socket: _socket} = server_state) do
    check_auth(server_state)
    |> with_ok(&pwd/1, server_state)
    |> update_connector_state(server_state)
    |> noreply()
  end

  def run(["CDUP"], state), do: run(["CWD", ".."], state)

  def run(["CWD", path], %{socket: _socket} = server_state) do
    check_auth(server_state)
    |> with_ok(&cwd/1, server_state, path: path)
    |> update_connector_state(server_state)
    |> noreply()
  end

  def run(["MKD", path], %{socket: _socket} = server_state) do
    check_auth(server_state)
    |> with_ok(&mkd/1, server_state, path: path)
    |> update_connector_state(server_state)
    |> noreply()
  end

  def run(["RMD", path], %{socket: _socket} = server_state) do
    check_auth(server_state)
    |> with_ok(&rmd/1, server_state, path: path)
    |> update_connector_state(server_state)
    |> noreply()
  end

  def run(["LIST", "-a"], server_state), do: run(["LIST", "-a", "."], server_state)

  def run(["LIST", "-a", path], %{socket: _socket} = server_state) do
    with {:ok, pasv} <- with_pasv_socket(server_state) do
      check_auth(server_state)
      |> with_ok(&list/1, server_state, pasv: pasv, path: path, include_hidden: true)
      |> update_connector_state(server_state)
      |> noreply()
    end
  end

  def run(["LIST"], server_state), do: run(["LIST", "."], server_state)

  def run(["LIST", path], %{socket: _socket} = server_state) do
    with {:ok, pasv} <- with_pasv_socket(server_state) do
      check_auth(server_state)
      |> with_ok(&list/1, server_state, pasv: pasv, path: path, include_hidden: false)
      |> update_connector_state(server_state)
      |> noreply()
    end
  end

  def run(["NLST", "-a"], server_state), do: run(["NLST", "-a", "."], server_state)

  def run(["NLST", "-a", path], %{socket: _socket} = server_state) do
    with {:ok, pasv} <- with_pasv_socket(server_state) do
      check_auth(server_state)
      |> with_ok(&nlst/1, server_state, pasv: pasv, path: path, include_hidden: true)
      |> update_connector_state(server_state)
      |> noreply()
    end
  end

  def run(["NLST"], state), do: run(["NLST", "."], state)

  def run(["NLST", path], %{socket: _socket} = server_state) do
    with {:ok, pasv} <- with_pasv_socket(server_state) do
      check_auth(server_state)
      |> with_ok(&nlst/1, server_state, pasv: pasv, path: path, include_hidden: false)
      |> update_connector_state(server_state)
      |> noreply()
    end
  end

  def run(["RETR", path], %{socket: _socket} = server_state) do
    with {:ok, pasv} <- with_pasv_socket(server_state) do
      check_auth(server_state)
      |> with_ok(&retr/1, server_state, pasv: pasv, path: path)
      |> update_connector_state(server_state)
      |> noreply()
    end
  end

  def run(["SIZE", path], %{socket: _socket} = server_state) do
    check_auth(server_state)
    |> with_ok(&size/1, server_state, path: path)
    |> update_connector_state(server_state)
    |> noreply()
  end

  def run(["STOR", path], %{socket: _socket} = server_state) do
    with {:ok, pasv} <- with_pasv_socket(server_state) do
      check_auth(server_state)
      |> with_ok(&stor/1, server_state, pasv: pasv, path: path)
      |> update_connector_state(server_state)
      |> noreply()
    end
  end

  def run(_, %{socket: socket} = state) do
    :ok = send_resp(502, "Command not implemented.", socket)
    {:noreply, state}
  end

  def with_ok(
        maybe_ok,
        fnc,
        %{
          socket: socket,
          storage_connector: connector,
          connector_state: connector_state
        },
        opts \\ []
      ) do
    maybe_ok
    |> case do
      :ok ->
        fnc.(%{
          socket: socket,
          storage_connector: connector,
          connector_state: connector_state,
          path: opts[:path],
          pasv: opts[:pasv],
          include_hidden: opts[:include_hidden]
        })

      _ ->
        connector_state
    end
  end

  defp check_auth(%{socket: socket, authenticator: auth, authenticator_state: auth_state}) do
    if auth.authenticated?(auth_state) do
      :ok
    else
      :ok = send_resp(530, "Not logged in.", socket)
      :err
    end
  end

  def update_connector_state(connector_state, server_state) do
    Map.put(server_state, :connector_state, connector_state)
  end

  def noreply(state) do
    {:noreply, state}
  end
end
