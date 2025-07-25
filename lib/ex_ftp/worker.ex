# SPDX-License-Identifier: Apache-2.0
defmodule ExFTP.Worker do
  @moduledoc """
  A module defining a `GenServer` which serves the FTP interface
  """

  use GenServer

  import Bitwise
  import ExFTP.Common
  import ExFTP.Storage.Common

  alias ExFTP.Auth.PassthroughAuth
  alias ExFTP.PassiveSocket
  alias ExFTP.Storage.FileConnector

  require Logger

  @impl GenServer
  def init(socket) do
    env = Application.get_all_env(:ex_ftp)
    ftp_addr = env[:ftp_addr] || "127.0.0.1"
    mix_env = env[:mix_env]
    connector = env[:storage_connector] || FileConnector
    authenticator = env[:authenticator] || PassthroughAuth
    server_name = env[:server_name] || :ExFTP

    {:ok, host} =
      ftp_addr
      |> to_charlist()
      |> :inet.parse_address()

    if mix_env != :test do
      {:ok, {ip_address, _port}} = :inet.peername(socket)
      ip_address_str = ip_address |> Tuple.to_list() |> Enum.join(".")
      Logger.info("Received FTP connection from #{ip_address_str}")
    end

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

  @impl GenServer
  def handle_info({:tcp, _socket, data}, state) do
    sanitized =
      String.trim(data)
      |> String.split(" ", parts: 2)
      |> case do
        ["PASS", _] -> "PASS *******"
        _ -> String.trim(data)
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

  def child_spec(arg) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [arg]},
      restart: :temporary
    }
  end

  def start_link(socket) do
    GenServer.start_link(__MODULE__, socket, name: __MODULE__)
  end

  defp parse(data) do
    data
    |> String.trim()
    |> String.split(" ", parts: 2)
  end

  defp run(["QUIT"], state) do
    quit(state)
  end

  defp run(["SYST"], %{socket: socket} = state) do
    send_resp(215, "UNIX Type: L8", socket)
    {:noreply, state}
  end

  defp run(["TYPE", type], %{socket: socket} = state) do
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

  defp run(["PASV"], %{socket: socket} = server_state) do
    case check_auth(server_state) do
      :ok ->
        {:ok, pasv} = PassiveSocket.start_link()

        host = Map.get(server_state, :host)
        {:ok, port} = PassiveSocket.get_port(pasv)
        pasv_string = ip_port_to_pasv(host, port)

        send_resp(227, "Entering Passive Mode (#{pasv_string}).", socket)
        {:noreply, %{server_state | pasv_socket: pasv}}

      _ ->
        {:noreply, server_state}
    end
  end

  defp run(["EPSV"], %{socket: socket} = server_state) do
    case check_auth(server_state) do
      :ok ->
        {:ok, pasv} = PassiveSocket.start_link()
        {:ok, port} = PassiveSocket.get_port(pasv)

        send_resp(229, "Entering Extended Passive Mode (|||#{port}|)", socket)
        {:noreply, %{server_state | pasv_socket: pasv}}

      _ ->
        {:noreply, server_state}
    end
  end

  defp run(["EPRT", _eport_info], %{socket: socket} = server_state) do
    with :ok <- check_auth(server_state) do
      send_resp(200, "EPRT command successful.", socket)
    end

    {:noreply, server_state}
  end

  # Auth Commands

  defp run(["USER", username], %{socket: socket, authenticator: authenticator} = server_state) do
    valid? = authenticator.valid_user?(username)

    server_state =
      if valid?,
        do:
          server_state
          |> Map.put(:authenticator_state, %{username: username}),
        else:
          server_state
          |> Map.put(:authenticator_state, %{authenticated: false})

    send_resp(331, "User name okay, need password.", socket)

    noreply(server_state)
  end

  defp run(
         ["PASS", password],
         %{socket: socket, authenticator: authenticator, authenticator_state: auth_state} = server_state
       ) do
    authenticator.login(password, auth_state)
    |> case do
      {:ok, auth_state} ->
        auth_state = Map.put(auth_state, :authenticated, true)

        send_resp(230, "Welcome.", socket)

        server_state
        |> Map.put(:authenticator_state, auth_state)
        |> noreply()

      {_, %{} = auth_state} ->
        send_resp(530, "Authentication failed.", socket)

        server_state
        |> Map.put(:authenticator_state, auth_state)
        |> noreply()

      _ ->
        send_resp(530, "Authentication failed.", socket)

        noreply(server_state)
    end
  end

  # Storage Connector Commands
  defp run(["PWD"], %{socket: _socket} = server_state) do
    server_state
    |> check_auth()
    |> with_ok(&pwd/1, server_state)
    |> update_connector_state(server_state)
    |> noreply()
  end

  defp run(["CDUP"], state), do: run(["CWD", ".."], state)

  defp run(["CWD", path], %{socket: _socket} = server_state) do
    server_state
    |> check_auth()
    |> with_ok(&cwd/1, server_state, path: path)
    |> update_connector_state(server_state)
    |> noreply()
  end

  defp run(["MKD", path], %{socket: _socket} = server_state) do
    server_state
    |> check_auth()
    |> with_ok(&mkd/1, server_state, path: path)
    |> update_connector_state(server_state)
    |> noreply()
  end

  defp run(["RMD", path], %{socket: _socket} = server_state) do
    server_state
    |> check_auth()
    |> with_ok(&rmd/1, server_state, path: path)
    |> update_connector_state(server_state)
    |> noreply()
  end

  defp run(["DELE", path], %{socket: _socket} = server_state) do
    server_state
    |> check_auth()
    |> with_ok(&dele/1, server_state, path: path)
    |> update_connector_state(server_state)
    |> noreply()
  end

  defp run(["LIST", "-a"], server_state), do: run(["LIST", "-a", "."], server_state)

  defp run(["LIST", "-a", path], %{socket: _socket} = server_state) do
    with {:ok, pasv} <- with_pasv_socket(server_state) do
      server_state
      |> check_auth()
      |> with_ok(&list/1, server_state, pasv: pasv, path: path, include_hidden: true)
      |> update_connector_state(server_state)
      |> noreply()
    end
  end

  defp run(["LIST"], server_state), do: run(["LIST", "."], server_state)

  defp run(["LIST", path], %{socket: _socket} = server_state) do
    with {:ok, pasv} <- with_pasv_socket(server_state) do
      server_state
      |> check_auth()
      |> with_ok(&list/1, server_state, pasv: pasv, path: path, include_hidden: false)
      |> update_connector_state(server_state)
      |> noreply()
    end
  end

  defp run(["NLST", "-a"], server_state), do: run(["NLST", "-a", "."], server_state)

  defp run(["NLST", "-a", path], %{socket: _socket} = server_state) do
    with {:ok, pasv} <- with_pasv_socket(server_state) do
      server_state
      |> check_auth()
      |> with_ok(&nlst/1, server_state, pasv: pasv, path: path, include_hidden: true)
      |> update_connector_state(server_state)
      |> noreply()
    end
  end

  defp run(["NLST"], state), do: run(["NLST", "."], state)

  defp run(["NLST", path], %{socket: _socket} = server_state) do
    with {:ok, pasv} <- with_pasv_socket(server_state) do
      server_state
      |> check_auth()
      |> with_ok(&nlst/1, server_state, pasv: pasv, path: path, include_hidden: false)
      |> update_connector_state(server_state)
      |> noreply()
    end
  end

  defp run(["RETR", path], %{socket: _socket} = server_state) do
    with {:ok, pasv} <- with_pasv_socket(server_state) do
      server_state
      |> check_auth()
      |> with_ok(&retr/1, server_state, pasv: pasv, path: path)
      |> update_connector_state(server_state)
      |> noreply()
    end
  end

  defp run(["SIZE", path], %{socket: _socket} = server_state) do
    server_state
    |> check_auth()
    |> with_ok(&size/1, server_state, path: path)
    |> update_connector_state(server_state)
    |> noreply()
  end

  defp run(["STOR", path], %{socket: _socket} = server_state) do
    with {:ok, pasv} <- with_pasv_socket(server_state) do
      server_state
      |> check_auth()
      |> with_ok(&stor/1, server_state, pasv: pasv, path: path)
      |> update_connector_state(server_state)
      |> noreply()
    end
  end

  defp run(_args, %{socket: socket} = state) do
    send_resp(502, "Command not implemented.", socket)
    {:noreply, state}
  end

  defp with_ok(
         maybe_ok,
         fnc,
         %{socket: socket, storage_connector: connector, connector_state: connector_state},
         opts \\ []
       ) do
    case maybe_ok do
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

  defp authenticate(auth, auth_state) do
    if auth.authenticated?(auth_state) do
      :ok
    end
  end

  defp get_auth_ttl do
    Application.get_env(:ex_ftp, :authenticator_config, %{})[:authenticated_ttl_ms] ||
      24 * 60 * 60 * 60 * 1000
  end

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
    if :ok == authenticate(auth, auth_state) do
      :ok
    else
      send_resp(530, "Not logged in.", socket)
      :error
    end
  end

  defp update_connector_state(connector_state, server_state) do
    Map.put(server_state, :connector_state, connector_state)
  end

  defp noreply(state) do
    {:noreply, state}
  end

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
      {:noreply, state}
    end
  end

  defp quit(%{socket: socket} = state) do
    Logger.info("Shutting down. Client closed connection.")

    send_resp(221, "Closing connection.", socket)

    :gen_tcp.close(socket)

    pasv = state[:pasv_socket]

    if pasv && Process.alive?(pasv) do
      PassiveSocket.close(pasv)
    end

    {:stop, :normal, state}
  end
end
