ExUnit.configure(formatters: [JUnitFormatter, ExUnit.CLIFormatter])
ExUnit.start()

defmodule ExFTP.TestHelper do
  @moduledoc false

  use ExUnit.Case

  import Bitwise

  def send(socket, cmd, args \\ []) do
    cmd = String.trim(cmd)

    arg_str =
      Enum.map_join(args, " ", fn arg -> String.trim(arg) end)

    cmd = String.trim("#{cmd} #{arg_str}")

    :ok = :gen_tcp.send(socket, "#{cmd}\r\n")
    socket
  end

  def expect_recv(socket, code, msg_start \\ "") do
    match = "#{code} #{msg_start}"
    {:ok, ^match <> _} = :gen_tcp.recv(socket, 0, 20_000)
    socket
  end

  def flush_recv(socket) do
    :gen_tcp.recv(socket, 0, 20_000)
    socket
  end

  def send_and_expect(socket, cmd, args, code, msg_start \\ "") do
    send(socket, cmd, args)
    expect_recv(socket, code, msg_start)
    socket
  end

  def read_fully(socket, data \\ <<>>) do
    case :gen_tcp.recv(socket, 0, 20_000) do
      {:ok, resp} -> read_fully(socket, data <> resp)
      {:error, :closed} -> {:ok, data}
    end
  end

  def setup_pasv_connection(%{socket: socket} = state) do
    send(socket, "PASV", [])

    assert {:ok, "227 Entering Passive Mode " <> ip_port_string} =
             :gen_tcp.recv(socket, 0, 20_000)

    [_, ip_port_string] = Regex.run(~r/\((.*)\)/, ip_port_string)

    assert [o1, o2, o3, o4, ip1, ip2] =
             ip_port_string
             |> String.trim()
             |> String.split(",")
             |> Enum.map(&String.to_integer/1)

    ip = {o1, o2, o3, o4}
    port = (ip1 <<< 8) + (255 &&& ip2)

    assert {:ok, pasv_socket} = :gen_tcp.connect(ip, port, [:binary, active: false])

    on_exit(:close_pasv_socket, fn -> :gen_tcp.close(pasv_socket) end)

    Map.put(state, :pasv_socket, pasv_socket)
  end

  def close_pasv(pasv), do: :gen_tcp.close(pasv)

  def get_socket do
    port = Application.get_env(:ex_ftp, :ftp_port)
    {:ok, socket} = :gen_tcp.connect({127, 0, 0, 1}, port, [:binary, active: false])
    {:ok, _} = :gen_tcp.recv(socket, 0, 10_000)

    on_exit(:close_socket, fn -> :gen_tcp.close(socket) end)
    socket
  end
end

defmodule ExFTP.StorageTester do
  @moduledoc false
  use ExUnit.Case

  import ExFTP.TestHelper

  def test_pwd(%{socket: socket}) do
    send_and_expect(socket, "PWD", [], 257, "\"/\" is the current directory")
  end

  def test_cwd_cdup(%{socket: socket}, tmp_dir) do
    send_and_expect(socket, "PWD", [], 257, "\"/\" is the current directory")

    socket
    |> send_and_expect("MKD", [tmp_dir], 257, "\"#{tmp_dir}\" directory created.")
    |> send_and_expect("CWD", [tmp_dir], 250, "Directory changed successfully.")
    |> send_and_expect("PWD", [], 257, "\"#{tmp_dir}\" is the current directory")
    |> send_and_expect("CDUP", [], 250, "Directory changed successfully.")
    |> send_and_expect("CDUP", [], 250, "Directory changed successfully.")
    |> send_and_expect("PWD", [], 257, "\"/\" is the current directory")

    socket
    |> send_and_expect(
      "CWD",
      [tmp_dir <> "/does-not-exist"],
      550,
      "Failed to change directory. Does not exist."
    )
    |> send_and_expect("PWD", [], 257, "\"/\" is the current directory")
  end

  def test_mkd_rmd(%{socket: socket} = state, dir_to_make) do
    # PWD
    send_and_expect(socket, "PWD", [], 257, "\"/\" is the current directory")

    # CWD tmp_dir
    # MKD dir_to_make
    send_and_expect(socket, "MKD", [dir_to_make], 257, "\"#{dir_to_make}\" directory created.")

    # LIST -a an empty dir
    %{socket: socket, pasv_socket: pasv_socket} = setup_pasv_connection(state)

    socket
    |> send_and_expect("CWD", [dir_to_make], 250, "Directory changed successfully.")
    |> send_and_expect("LIST", ["-a"], 150)

    assert {:ok, listing} = read_fully(pasv_socket)
    expect_recv(socket, 226, "Directory send OK.")
    assert String.trim(listing) != ""

    # List an empty dir
    %{socket: socket, pasv_socket: pasv_socket} = setup_pasv_connection(state)

    socket
    |> send_and_expect("CWD", [dir_to_make], 250, "Directory changed successfully.")
    |> send_and_expect("LIST", [], 150)

    assert {:ok, listing} = read_fully(pasv_socket)
    expect_recv(socket, 226, "Directory send OK.")
    assert String.trim(listing) == ""

    # NLST an empty dir

    %{socket: socket, pasv_socket: pasv_socket} = setup_pasv_connection(state)

    socket
    |> send_and_expect("CWD", [dir_to_make], 250, "Directory changed successfully.")
    |> send_and_expect("NLST", [], 150)

    assert {:ok, listing} = read_fully(pasv_socket)
    expect_recv(socket, 226, "Directory send OK.")
    assert String.trim(listing) == ""

    # call it twice
    send_and_expect(socket, "MKD", [dir_to_make], 521, "\"#{dir_to_make}\" directory already exists")

    # CWD dir_to_make
    # RMD dir_to_make
    socket
    |> send_and_expect("CWD", [dir_to_make], 250, "Directory changed successfully.")
    |> send_and_expect("RMD", [dir_to_make], 250, "\"#{dir_to_make}\" directory removed.")

    # verify you've been kicked out
    # PWD
    send_and_expect(socket, "PWD", [], 257)
  end

  def test_list_a(state, w_dir) do
    %{socket: socket, pasv_socket: pasv_socket} = setup_pasv_connection(state)

    socket
    |> send_and_expect("CWD", [w_dir], 250, "Directory changed successfully.")
    |> send_and_expect("LIST", ["-a"], 150)

    assert {:ok, listing} = read_fully(pasv_socket)
    expect_recv(socket, 226, "Directory send OK.")
    String.trim(listing)
  end

  def test_list(state, w_dir) do
    %{socket: socket, pasv_socket: pasv_socket} = setup_pasv_connection(state)

    socket
    |> send_and_expect("CWD", [w_dir], 250, "Directory changed successfully.")
    |> send_and_expect("LIST", [], 150)

    assert {:ok, listing} = read_fully(pasv_socket)
    expect_recv(socket, 226, "Directory send OK.")
    String.trim(listing)
  end

  def test_nlst(state, w_dir) do
    %{socket: socket, pasv_socket: pasv_socket} = setup_pasv_connection(state)

    socket
    |> send_and_expect("CWD", [w_dir], 250, "Directory changed successfully.")
    |> send_and_expect("NLST", [], 150)

    assert {:ok, listing} = read_fully(pasv_socket)

    expect_recv(socket, 226, "Directory send OK.")
    String.trim(listing)
  end

  def test_nlst_a(state, w_dir) do
    %{socket: socket, pasv_socket: pasv_socket} = setup_pasv_connection(state)

    socket
    |> send_and_expect("CWD", [w_dir], 250, "Directory changed successfully.")
    |> send_and_expect("NLST", ["-a"], 150)

    assert {:ok, listing} = read_fully(pasv_socket)

    expect_recv(socket, 226, "Directory send OK.")
    String.trim(listing)
  end

  def test_retr(%{socket: socket} = state, w_dir, paths_to_download) do
    send_and_expect(socket, "CWD", [w_dir], 250, "Directory changed successfully.")
    refute Enum.empty?(paths_to_download)

    Enum.each(paths_to_download, fn file ->
      %{pasv_socket: pasv_socket} = setup_pasv_connection(state)
      send_and_expect(socket, "RETR", [file], 150)
      assert {:ok, bytes} = read_fully(pasv_socket)
      refute byte_size(bytes) == 0
      expect_recv(socket, 226, "Transfer complete.")
    end)

    # try to retrieve something that doesn't exist
    file = "/does-not-exist"
    %{pasv_socket: pasv_socket} = setup_pasv_connection(state)
    send_and_expect(socket, "RETR", [file], 150)
    assert {:ok, bytes} = read_fully(pasv_socket)
    assert byte_size(bytes) == 0
    expect_recv(socket, 451, "File not found.")
  end

  def test_size(state, w_dir) do
    %{socket: socket, pasv_socket: pasv_socket} = setup_pasv_connection(state)

    socket
    |> send_and_expect("CWD", [w_dir], 250, "Directory changed successfully.")
    |> send_and_expect("NLST", ["-a"], 150)

    assert {:ok, listing} = read_fully(pasv_socket)
    expect_recv(socket, 226, "Directory send OK.")
    files_to_size = listing |> String.split("\r\n") |> Enum.reject(&(&1 == ""))

    Enum.map(files_to_size, fn file ->
      send_and_expect(socket, "SIZE", [String.trim(file)], 213)
    end)
  end

  def test_stor(%{socket: socket} = state, w_dir, files_to_store) do
    socket
    |> send_and_expect("MKD", [w_dir], 257, "\"#{w_dir}\" directory created.")
    |> send_and_expect("CWD", [w_dir], 250, "Directory changed successfully.")

    Enum.each(files_to_store, fn file ->
      %{pasv_socket: pasv_socket} = setup_pasv_connection(state)

      send_and_expect(socket, "STOR", [file], 150)

      path = Path.join(File.cwd!(), file)

      data =
        path
        |> File.read!()

      :ok = :gen_tcp.send(pasv_socket, data)

      close_pasv(pasv_socket)

      expect_recv(socket, 226, "Transfer Complete.")
      :timer.sleep(400)
      :timer.sleep(100)

      send_and_expect(socket, "SIZE", [file], 213)
    end)
  end

  def test_dele(%{socket: socket} = state, w_dir, files_to_store) do
    test_stor(state, w_dir, files_to_store)

    Enum.each(files_to_store, fn file ->
      socket
      |> send_and_expect("DELE", [file], 250)
      |> send_and_expect("SIZE", [file], 550)
    end)

    # test delete a file that doesn't exist
    file = "/does-not-exist"

    socket
    |> send_and_expect("DELE", [file], 550, "Failed to remove file.")
  end
end
