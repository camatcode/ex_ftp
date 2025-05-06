defmodule FTP2Cloud.Worker do
  @moduledoc false

  use GenServer
  import Bitwise

  require Logger

  alias FTP2Cloud.PassiveSocket

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
       ftp_config: nil,
       virtual_directories: []
     }}
  end

  def handle_info({:tcp, _socket, data}, state) do
    sanitized =
      if String.starts_with?(inspect(data), "\"PASS") do
        "PASS *******\r\n"
      else
        inspect(data)
      end

    Logger.info("Received FTP message:\t#{sanitized}")

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

  def run(["CDUP"], state) do
    run(["CWD", ".."], state)
  end

  def run(["CWD", path], %{socket: socket} = state) do
    with {:ok, _user} <- with_active_user(state) do
      destination_prefix = change_prefix(state.prefix, path)

      if destination_prefix == "/" do
        :ok = send_resp(250, "Directory changed successfully.", socket)
        {:noreply, %{state | prefix: destination_prefix}}
      else
        dest_parent_prefix = change_prefix(state.prefix, "#{path}/..")
        possible_new_state = %{state | prefix: dest_parent_prefix}

        get_current_prefix(possible_new_state)
        |> get_listing(possible_new_state)
        |> Enum.filter(fn item ->
          String.starts_with?(item, "d") &&
            String.ends_with?(item, Path.basename(destination_prefix))
        end)
        |> Enum.empty?()
        |> case do
          true ->
            :ok = send_resp(550, "Failed to change directory.", socket)
            {:noreply, state}

          false ->
            :ok = send_resp(250, "Directory changed successfully.", socket)
            {:noreply, %{state | prefix: destination_prefix}}
        end
      end
    end
  end

  def run(["MKD", path], %{socket: socket} = state) do
    with {:ok, _user} <- with_active_user(state) do
      virtual_prefix = change_prefix(state.prefix, path)

      {dirs_to_add, _} =
        virtual_prefix
        |> Path.split()
        |> Enum.map_reduce("/", fn part, acc ->
          {change_prefix(state.prefix, Path.join(acc, part)),
           change_prefix(state.prefix, Path.join(acc, part))}
        end)

      virtual_directories = Enum.uniq(state.virtual_directories ++ dirs_to_add)
      :ok = send_resp(257, "Directory made successfully.", socket)
      {:noreply, %{state | virtual_directories: virtual_directories}}
    end
  end

  def run(["LIST", "-a"], %{socket: socket} = state) do
    with {:ok, _user} <- with_active_user(state),
         {:ok, pasv} <- with_pasv_socket(state) do
      :ok = send_resp(150, "Here comes the directory listing.", socket)

      prefix =
        get_current_prefix(state)

      hidden = [
        make_dummy_directory_listing("."),
        make_dummy_directory_listing("..")
      ]

      listing = hidden ++ get_listing(prefix, state)
      write_directory_list(pasv, listing)

      :ok = send_resp(226, "Directory send OK.", socket)
      {:noreply, state}
    end
  end

  def run(["LIST"], %{socket: socket} = state) do
    with {:ok, _user} <- with_active_user(state),
         {:ok, pasv} <- with_pasv_socket(state) do
      :ok = send_resp(150, "Here comes the directory listing.", socket)

      prefix =
        get_current_prefix(state)

      listing = get_listing(prefix, state)
      write_directory_list(pasv, listing)

      :ok = send_resp(226, "Directory send OK.", socket)
      {:noreply, state}
    end
  end

  def run(["NLST"], state), do: run(["NLST", ""], state)

  def run(["NLST", path], %{socket: socket} = state) do
    with {:ok, _user} <- with_active_user(state),
         {:ok, pasv} <- with_pasv_socket(state) do
      :ok = send_resp(150, "Opening ASCII mode data connection for file list", socket)

      prefix =
        get_current_prefix(state)
        |> Path.join(path)

      listing =
        get_name_listing(prefix, state)

      write_directory_list(pasv, listing)

      :ok = send_resp(226, "Transfer Complete.", socket)
      {:noreply, state}
    end
  end

  def run(["PASS", _password], %{socket: _socket, username: _username} = state) do
    # TODO
    {:noreply, state}
  end

  def run(["PASV"], %{socket: socket} = state) do
    with {:ok, _user} <- with_active_user(state) do
      # TODO opts?
      {:ok, pasv} = PassiveSocket.start_link()

      host = Map.get(state, :host)
      {:ok, port} = PassiveSocket.get_port(pasv)

      pasv_string = ip_port_to_pasv(host, port)

      :ok = send_resp(227, "Entering Passive Mode (#{pasv_string}).", socket)
      {:noreply, %{state | pasv_socket: pasv}}
    end
  end

  def run(["EPSV"], %{socket: socket} = state) do
    with {:ok, _user} <- with_active_user(state) do
      # TODO opts?
      {:ok, pasv} = PassiveSocket.start_link()
      {:ok, port} = PassiveSocket.get_port(pasv)

      :ok = send_resp(229, "Entering Extended Passive Mode (|||#{port}|)", socket)
      {:noreply, %{state | pasv_socket: pasv}}
    end
  end

  def run(["EPRT", _eport_info], %{socket: socket} = state) do
    with {:ok, _user} <- with_active_user(state) do
      :ok = send_resp(200, "EPRT command successful.", socket)
      {:noreply, state}
    end
  end

  def run(["PWD"], %{socket: socket} = state) do
    :ok = send_resp(257, "\"#{state.prefix}\" is the current directory", socket)
    {:noreply, state}
  end

  def run(["QUIT"], %{socket: socket, pasv_socket: pasv} = state) do
    Logger.info("Shutting down. Client closed connection.")

    :ok = send_resp(221, "Closing connection.", socket)

    :gen_tcp.close(socket)

    if pasv && Process.alive?(pasv) do
      PassiveSocket.close(pasv)
    end

    {:stop, :normal, state}
  end

  def run(["RETR", path], %{socket: socket} = state) do
    with {:ok, _user} <- with_active_user(state),
         {:ok, _pasv} <- with_pasv_socket(state) do
      :ok = send_resp(150, "Opening BINARY mode data connection for #{path}", socket)
      # TODO
      :ok = send_resp(451, "File not found.", socket)

      {:noreply, state}
    end
  end

  def run(["SIZE", _path], %{socket: socket} = state) do
    with {:ok, _user} <- with_active_user(state) do
      # TODO
      :ok = send_resp(550, "Could not get file size.", socket)

      {:noreply, state}
    end
  end

  def run(["STOR", _path], %{socket: socket} = state) do
    with {:ok, _user} <- with_active_user(state),
         {:ok, _pasv} <- with_pasv_socket(state) do
      :ok = send_resp(150, "Ok to send data.", socket)

      # TODO

      {:noreply, state}
    end
  end

  def run(["SYST"], %{socket: socket} = state) do
    :ok = send_resp(215, "UNIX Type: L8", socket)
    {:noreply, state}
  end

  def run(["TYPE", type], %{socket: socket} = state) do
    with {:ok, _user} <- with_active_user(state) do
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
  end

  def run(["USER", username], %{socket: socket} = state) do
    :ok = send_resp(331, "User name okay, need password.", socket)
    {:noreply, %{state | username: username}}
  end

  def run(_, %{socket: socket} = state) do
    :ok = send_resp(502, "Command not implemented.", socket)
    {:noreply, state}
  end

  defp write_directory_list(pasv, listing) do
    if Enum.empty?(listing) do
      PassiveSocket.write(pasv, "", close_after_write: true)
    else
      :ok =
        listing
        |> Enum.each(&PassiveSocket.write(pasv, &1, close_after_write: false))

      PassiveSocket.close(pasv)
    end
  end

  defp change_prefix(current_prefix, path) do
    cond do
      String.starts_with?(path, "/") ->
        Path.expand(path)

      String.starts_with?(path, "~") ->
        String.replace(path, "~", "/") |> Path.expand()

      true ->
        Path.join(current_prefix, path)
        |> Path.expand()
    end
  end

  defp get_current_prefix(%{user_prefix: user_prefix, prefix: prefix}) do
    Path.join(user_prefix, prefix) <> "/"
  end

  defp get_listing(_prefix, _state) do
    # TODO
  end

  defp make_dummy_directory_listing(dir_name) do
    "drwxr-xr-x   10 0        0            4096 Jan 01  1970 #{dir_name}"
  end

  defp get_name_listing(_prefix, _state) do
    # TODO
  end

  defp ip_port_to_pasv(ip, port) do
    upper_port = port >>> 8
    lower_port = port &&& 255
    {a, b, c, d} = ip
    # Convert IP and port (e.g. 64943) to (192,168,1,22,253,175)
    "#{a},#{b},#{c},#{d},#{upper_port},#{lower_port}"
  end

  defp send_resp(code, msg, socket) do
    response = "#{code} #{msg}\r\n"
    Logger.info("Sending FTP response:\t#{inspect(response)}")
    :gen_tcp.send(socket, response)
  end

  defp with_active_user(%{current_user: user} = state) do
    if user do
      {:ok, user}
    else
      :ok = send_resp(530, "Authentication required.", Map.get(state, :socket))
      {:noreply, state}
    end
  end

  defp with_pasv_socket(%{pasv_socket: pasv} = state) do
    if pasv && Process.alive?(pasv) do
      {:ok, pasv}
    else
      :ok = send_resp(550, "LIST failed. PASV mode required.", Map.get(state, :socket))
      {:noreply, state}
    end
  end
end
