# SPDX-License-Identifier: Apache-2.0
defmodule ExFTP.Worker do
  @moduledoc """
  A module defining a `Handler` which serves the FTP interface
  """
  use ThousandIsland.Handler

  import Bitwise
  import ExFTP.Common
  import ExFTP.Storage.Common

  alias __MODULE__, as: Worker
  alias ExFTP.Auth.PassthroughAuth
  alias ExFTP.PassiveSocket
  alias ExFTP.Storage.FileConnector

  require Logger

  defstruct [
    :socket,
    :storage_connector,
    :authenticator,
    :host,
    pasv_socket: nil,
    type: :ascii,
    connector_state: %{current_working_directory: "/"},
    authenticator_state: %{}
  ]

  @impl ThousandIsland.Handler
  def handle_connection(socket, _options) do
    env = Application.get_all_env(:ex_ftp)
    ftp_addr = env[:ftp_addr] || "127.0.0.1"
    mix_env = env[:mix_env]
    connector = env[:storage_connector] || FileConnector
    authenticator = env[:authenticator] || PassthroughAuth
    server_name = env[:server_name] || :ExFTP
    storage_config = env[:storage_config] || %{}
    on_transfer_complete = storage_config[:on_transfer_complete]

    {:ok, host} =
      ftp_addr
      |> to_charlist()
      |> :inet.parse_address()

    if mix_env != :test do
      {:ok, {ip_address, _port}} = ThousandIsland.Socket.peername(socket)
      ip_address_str = ip_address |> Tuple.to_list() |> Enum.join(".")
      Logger.info("Received FTP connection from #{ip_address_str}")
    end

    send_resp(220, "Hello from #{server_name}.", socket)

    connector_state = %{current_working_directory: "/"}

    connector_state =
      if on_transfer_complete do
        Map.put(connector_state, :on_transfer_complete, on_transfer_complete)
      else
        connector_state
      end

    %Worker{
      socket: socket,
      host: host,
      pasv_socket: nil,
      type: :ascii,
      storage_connector: connector,
      connector_state: connector_state,
      authenticator: authenticator,
      authenticator_state: %{}
    }
    |> continue()
  end

  @impl ThousandIsland.Handler
  def handle_data(data, socket, state) do
    data
    |> String.trim()
    |> String.split(" ", parts: 2)
    |> log_message(data)
    |> run(socket, state)
  end

  @impl ThousandIsland.Handler
  def handle_close(_socket, state), do: PassiveSocket.close(state.pasv_socket)

  @impl ThousandIsland.Handler
  def handle_shutdown(_socket, state), do: PassiveSocket.close(state.pasv_socket)

  @impl ThousandIsland.Handler
  def handle_timeout(_socket, state), do: PassiveSocket.close(state.pasv_socket)

  @impl GenServer
  def handle_info({:send, msg}, {socket, state}) do
    ThousandIsland.Socket.send(socket, msg)
    {:noreply, {socket, state}, socket.read_timeout}
  end

  @impl GenServer
  def handle_info(:read_complete, {socket, state}) do
    Logger.debug("Read complete")
    PassiveSocket.close(state.pasv_socket)
    {:noreply, {socket, %{state | pasv_socket: nil}}, socket.read_timeout}
  end

  @impl GenServer
  def handle_info({:tcp_closed, _}, state), do: {:stop, :normal, state}

  @impl GenServer
  def handle_info({:tcp_error, _}, state), do: {:stop, :normal, state}

  @impl GenServer
  def handle_info({:EXIT, _pid, :normal}, {socket, state}) do
    state = %{state | pasv_socket: nil}
    {:noreply, {socket, state}, socket.read_timeout}
  end

  defp run(["QUIT"], socket, state), do: quit(socket, state)

  defp run(["SYST"], socket, state) do
    send_resp(215, "UNIX Type: L8", socket)
    continue(state)
  end

  defp run(["TYPE", type], socket, state) do
    type
    |> case do
      "I" ->
        send_resp(200, "Switching to binary mode.", socket)
        %{state | type: :image}

      "A" ->
        send_resp(200, "Switching to ASCII mode.", socket)
        %{state | type: :ascii}

      _ ->
        send_resp(504, "Unsupported transfer type.", socket)
        state
    end
    |> continue()
  end

  defp run(["PASV"], socket, server_state) do
    case check_auth(server_state) do
      :ok ->
        {:ok, pasv} = PassiveSocket.start_link()

        host = Map.get(server_state, :host)
        {:ok, port} = PassiveSocket.get_port(pasv)
        pasv_string = ip_port_to_pasv(host, port)

        send_resp(227, "Entering Passive Mode (#{pasv_string}).", socket)
        %{server_state | pasv_socket: pasv}

      _ ->
        server_state
    end
    |> continue()
  end

  defp run(["EPSV"], socket, server_state) do
    case check_auth(server_state) do
      :ok ->
        {:ok, pasv} = PassiveSocket.start_link()
        {:ok, port} = PassiveSocket.get_port(pasv)

        send_resp(229, "Entering Extended Passive Mode (|||#{port}|)", socket)
        %{server_state | pasv_socket: pasv}

      _ ->
        server_state
    end
    |> continue()
  end

  defp run(["EPRT", _eport_info], socket, server_state) do
    with :ok <- check_auth(server_state) do
      send_resp(200, "EPRT command successful.", socket)
    end

    continue(server_state)
  end

  # Auth Commands

  defp run(["USER", username], socket, %{authenticator: authenticator} = server_state) do
    valid? = authenticator.valid_user?(username)

    server_state =
      if valid?,
        do: Map.put(server_state, :authenticator_state, %{username: username}),
        else: Map.put(server_state, :authenticator_state, %{authenticated: false})

    send_resp(331, "User name okay, need password.", socket)

    continue(server_state)
  end

  defp run(
         ["PASS", password],
         socket,
         %{authenticator: authenticator, authenticator_state: auth_state, connector_state: connector_state} =
           server_state
       ) do
    authenticator.login(password, auth_state)
    |> case do
      {:ok, auth_state} ->
        auth_state = Map.put(auth_state, :authenticated, true)
        connector_state = Map.put(connector_state, :authenticator_state, auth_state)

        send_resp(230, "Welcome.", socket)

        server_state
        |> Map.put(:authenticator_state, auth_state)
        |> Map.put(:connector_state, connector_state)
        |> continue()

      {_, %{} = auth_state} ->
        send_resp(530, "Authentication failed.", socket)

        server_state
        |> Map.put(:authenticator_state, auth_state)
        |> continue()

      _ ->
        send_resp(530, "Authentication failed.", socket)

        continue(server_state)
    end
  end

  # Storage Connector Commands
  defp run(["PWD"], socket, server_state) do
    server_state
    |> check_auth()
    |> with_ok(&pwd/1, socket, server_state)
    |> update_connector_state(server_state)
    |> continue()
  end

  defp run(["CDUP"], socket, state), do: run(["CWD", ".."], socket, state)

  defp run(["CWD", path], socket, server_state) do
    server_state
    |> check_auth()
    |> with_ok(&cwd/1, socket, server_state, path: path)
    |> update_connector_state(server_state)
    |> continue()
  end

  defp run(["MKD", path], socket, server_state) do
    server_state
    |> check_auth()
    |> with_ok(&mkd/1, socket, server_state, path: path)
    |> update_connector_state(server_state)
    |> continue()
  end

  defp run(["RMD", path], socket, server_state) do
    server_state
    |> check_auth()
    |> with_ok(&rmd/1, socket, server_state, path: path)
    |> update_connector_state(server_state)
    |> continue()
  end

  defp run(["DELE", path], socket, server_state) do
    server_state
    |> check_auth()
    |> with_ok(&dele/1, socket, server_state, path: path)
    |> update_connector_state(server_state)
    |> continue()
  end

  defp run(["LIST", "-a"], socket, server_state), do: run(["LIST", "-a", "."], socket, server_state)

  defp run(["LIST", "-a", path], socket, server_state) do
    with {:ok, pasv} <- with_pasv_socket(server_state) do
      server_state
      |> check_auth()
      |> with_ok(&list/1, socket, server_state, pasv: pasv, path: path, include_hidden: true)
      |> update_connector_state(server_state)
      |> continue()
    end
  end

  defp run(["LIST"], socket, server_state), do: run(["LIST", "."], socket, server_state)

  defp run(["LIST", path], socket, server_state) do
    with {:ok, pasv} <- with_pasv_socket(server_state) do
      server_state
      |> check_auth()
      |> with_ok(&list/1, socket, server_state, pasv: pasv, path: path, include_hidden: false)
      |> update_connector_state(server_state)
      |> continue()
    end
  end

  defp run(["NLST", "-a"], socket, server_state), do: run(["NLST", "-a", "."], socket, server_state)

  defp run(["NLST", "-a", path], socket, server_state) do
    with {:ok, pasv} <- with_pasv_socket(server_state) do
      server_state
      |> check_auth()
      |> with_ok(&nlst/1, socket, server_state, pasv: pasv, path: path, include_hidden: true)
      |> update_connector_state(server_state)
      |> continue()
    end
  end

  defp run(["NLST"], socket, state), do: run(["NLST", "."], socket, state)

  defp run(["NLST", path], socket, server_state) do
    with {:ok, pasv} <- with_pasv_socket(server_state) do
      server_state
      |> check_auth()
      |> with_ok(&nlst/1, socket, server_state, pasv: pasv, path: path, include_hidden: false)
      |> update_connector_state(server_state)
      |> continue()
    end
  end

  defp run(["RETR", path], socket, server_state) do
    with {:ok, pasv} <- with_pasv_socket(server_state) do
      server_state
      |> check_auth()
      |> with_ok(&retr/1, socket, server_state, pasv: pasv, path: path)
      |> update_connector_state(server_state)
      |> continue()
    end
  end

  defp run(["SIZE", path], socket, server_state) do
    server_state
    |> check_auth()
    |> with_ok(&size/1, socket, server_state, path: path)
    |> update_connector_state(server_state)
    |> continue()
  end

  defp run(["STOR", path], socket, server_state) do
    with {:ok, pasv} <- with_pasv_socket(server_state) do
      server_state
      |> check_auth()
      |> with_ok(&stor/1, socket, server_state, pasv: pasv, path: path)
      |> update_connector_state(server_state)
      |> continue()
    end
  end

  defp run(_args, socket, state) do
    send_resp(502, "Command not implemented.", socket)
    continue(state)
  end

  defp with_ok(result, fnc, socket, state, opts \\ [])

  defp with_ok(:ok, fnc, socket, state, opts),
    do:
      fnc.(%{
        socket: socket,
        storage_connector: state.storage_connector,
        connector_state: state.connector_state,
        path: opts[:path],
        pasv: opts[:pasv],
        include_hidden: opts[:include_hidden]
      })

  defp with_ok(_other, _fnc, _socket, state, _opts), do: state.connector_state

  defp authenticate(auth, auth_state) do
    if auth.authenticated?(auth_state),
      do: :ok,
      else: :not_authenticated
  end

  defp get_auth_ttl,
    do: Application.get_env(:ex_ftp, :authenticator_config, %{})[:authenticated_ttl_ms] || to_timeout(day: 1)

  defp check_auth(%{socket: socket, authenticator: auth, authenticator_state: %{username: username} = auth_state})
       when not is_nil(username) do
    :auth_cache
    |> Cachex.get_and_update(username, fn
      nil ->
        auth
        |> authenticate(auth_state)
        |> case do
          :ok -> {:commit, :ok, expire: get_auth_ttl()}
          _ -> {:ignore, nil}
        end

      val ->
        {:ignore, val}
    end)
    |> case do
      {_, nil} ->
        send_resp(530, "Not logged in.", socket)
        :error

      {_, _} ->
        :ok
    end
  end

  defp check_auth(%{socket: socket, authenticator: auth, authenticator_state: auth_state}) do
    authenticate(auth, auth_state)
    |> case do
      :ok ->
        :ok

      _ ->
        send_resp(530, "Not logged in.", socket)
        :error
    end
  end

  defp update_connector_state(connector_state, server_state) do
    %{server_state | connector_state: connector_state}
  end

  defp continue(state), do: {:continue, state}

  defp ip_port_to_pasv(ip, port) do
    upper_port = port >>> 8
    lower_port = port &&& 255
    {a, b, c, d} = ip
    # Convert IP and port (e.g. 64943) to (192,168,1,22,253,175)
    "#{a},#{b},#{c},#{d},#{upper_port},#{lower_port}"
  end

  defp with_pasv_socket(%{pasv_socket: pasv} = state) do
    if pasv && Process.alive?(pasv) do
      {:ok, pasv}
    else
      send_resp(550, "CMD failed. PASV mode required.", Map.get(state, :socket))
      continue(state)
    end
  end

  defp quit(socket, state) do
    Logger.info("Shutting down. Client closed connection.")

    send_resp(221, "Closing connection.", socket)

    PassiveSocket.close(state.pasv_socket)

    {:close, %{state | pasv_socket: nil}}
  end

  defp log_message(["PASS", _] = message, _data) do
    Logger.info("Received FTP message:\t#{inspect("PASS *******")}")
    message
  end

  defp log_message(message, data) do
    Logger.info("Received FTP message:\t#{inspect(data)}")
    message
  end
end
