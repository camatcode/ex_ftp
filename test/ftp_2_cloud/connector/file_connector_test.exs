defmodule FTP2Cloud.Connector.FileConnectorTest do
  @moduledoc false

  import Bitwise
  use ExUnit.Case
  doctest FTP2Cloud.Connector.FileConnector

  setup do
    Application.put_env(:ftp_2_cloud, :authenticator, FTP2Cloud.Auth.PassthroughAuth)
    {:ok, socket} = :gen_tcp.connect({127, 0, 0, 1}, 4041, [:binary, active: false])
    {:ok, _} = :gen_tcp.recv(socket, 0, 10_000)

    on_exit(:close_socket, fn -> :gen_tcp.close(socket) end)

    username = Faker.Internet.user_name()
    password = Faker.Internet.slug()
    :ok = :gen_tcp.send(socket, "USER #{username}\r\n")
    assert {:ok, "331 User name okay, need password" <> _} = :gen_tcp.recv(socket, 0, 5_000)

    :ok = :gen_tcp.send(socket, "PASS #{password}\r\n")
    match = "230 Welcome #{username}."
    assert {:ok, ^match <> _} = :gen_tcp.recv(socket, 0, 5_000)

    %{socket: socket, username: username, password: password}
  end

  test "PWD", %{socket: socket, password: password} do
    :ok = :gen_tcp.send(socket, "PWD\r\n")

    assert {:ok, "257 \"/\" is the current directory" <> _} =
             :gen_tcp.recv(socket, 0, 5_000)

    # root can't PWD with passthrough auth
    :ok = :gen_tcp.send(socket, "USER root\r\n")
    assert {:ok, "331 User name okay, need password" <> _} = :gen_tcp.recv(socket, 0, 5_000)

    :ok = :gen_tcp.send(socket, "PASS #{password}\r\n")
    match = "530 Authentication failed."
    assert {:ok, ^match <> _} = :gen_tcp.recv(socket, 0, 5_000)

    :ok = :gen_tcp.send(socket, "PWD\r\n")

    {:ok, "530 Not logged in" <> _} =
      :gen_tcp.recv(socket, 0, 5_000)
  end

  test "CWD / CDUP", %{socket: socket, password: _password} do
    # PWD
    :ok = :gen_tcp.send(socket, "PWD\r\n")

    assert {:ok, "257 \"/\" is the current directory" <> _} =
             :gen_tcp.recv(socket, 0, 5_000)

    tmp_dir = System.tmp_dir!()
    # CWD tmp_dir
    :ok = :gen_tcp.send(socket, "CWD #{tmp_dir}\r\n")
    assert {:ok, "250 Directory changed successfully." <> _} = :gen_tcp.recv(socket, 0, 5_000)

    # PWD
    :ok = :gen_tcp.send(socket, "PWD\r\n")
    match = "257 \"#{tmp_dir}\" is the current directory"
    {:ok, ^match <> _} = :gen_tcp.recv(socket, 0, 5_000)

    # CDUP
    :ok = :gen_tcp.send(socket, "CDUP\r\n")
    assert {:ok, "250 Directory changed successfully." <> _} = :gen_tcp.recv(socket, 0, 5_000)

    # CDUP
    :ok = :gen_tcp.send(socket, "CDUP\r\n")
    assert {:ok, "250 Directory changed successfully." <> _} = :gen_tcp.recv(socket, 0, 5_000)

    # PWD
    :ok = :gen_tcp.send(socket, "PWD\r\n")

    assert {:ok, "257 \"/\" is the current directory" <> _} =
             :gen_tcp.recv(socket, 0, 5_000)

    # CWD does-not-exist
    :ok = :gen_tcp.send(socket, "CWD does-not-exist\r\n")

    assert {:ok, "550 Failed to change directory. Does not exist." <> _} =
             :gen_tcp.recv(socket, 0, 5_000)

    # PWD
    :ok = :gen_tcp.send(socket, "PWD\r\n")

    assert {:ok, "257 \"/\" is the current directory" <> _} =
             :gen_tcp.recv(socket, 0, 5_000)
  end

  test "MKD / RMD", %{socket: socket, password: _password} do
    # PWD
    :ok = :gen_tcp.send(socket, "PWD\r\n")

    assert {:ok, "257 \"/\" is the current directory" <> _} =
             :gen_tcp.recv(socket, 0, 5_000)

    tmp_dir = System.tmp_dir!()
    dir_to_make = Path.join(tmp_dir, Faker.Internet.slug())
    refute File.exists?(dir_to_make)
    on_exit(fn -> File.rm_rf!(dir_to_make) end)

    # CWD tmp_dir
    :ok = :gen_tcp.send(socket, "CWD #{tmp_dir}\r\n")
    assert {:ok, "250 Directory changed successfully." <> _} = :gen_tcp.recv(socket, 0, 5_000)

    # MKD dir_to_make
    :ok = :gen_tcp.send(socket, "MKD #{dir_to_make}\r\n")
    match = "257 \"#{dir_to_make}\" directory created."
    assert {:ok, ^match <> _} = :gen_tcp.recv(socket, 0, 5_000)
    assert File.exists?(dir_to_make)

    # CWD dir_to_make
    :ok = :gen_tcp.send(socket, "CWD #{dir_to_make}\r\n")
    assert {:ok, "250 Directory changed successfully." <> _} = :gen_tcp.recv(socket, 0, 5_000)

    # RMD dir_to_make
    :ok = :gen_tcp.send(socket, "RMD #{dir_to_make}\r\n")
    match = "250 \"#{dir_to_make}\" directory removed."
    assert {:ok, ^match <> _} = :gen_tcp.recv(socket, 0, 5_000)
    refute File.exists?(dir_to_make)

    # verify you've been kicked out
    # PWD
    :ok = :gen_tcp.send(socket, "PWD\r\n")

    match = "257 \"#{tmp_dir}\" is the current directory"

    assert {:ok, ^match <> _} =
             :gen_tcp.recv(socket, 0, 5_000)
  end

  test "LIST -a", state do
    %{socket: socket, pasv_socket: pasv_socket} = setup_pasv_connection(state)

    # CWD w_dir
    w_dir = File.cwd!()
    :ok = :gen_tcp.send(socket, "CWD #{w_dir}\r\n")
    assert {:ok, "250 Directory changed successfully." <> _} = :gen_tcp.recv(socket, 0, 5_000)

    # LIST -a
    :ok = :gen_tcp.send(socket, "LIST -a\r\n")
    assert {:ok, "150 " <> _} = :gen_tcp.recv(socket, 0, 5_000)

    assert {:ok, listing} = read_fully(pasv_socket)

    parts = String.split(listing, "\r\n")
    refute Enum.empty?(parts)

    files_to_find = File.ls!(w_dir)
    refute Enum.empty?(files_to_find)

    Enum.each(files_to_find, fn file_to_find ->
      assert [_found] = Enum.filter(parts, fn part -> String.ends_with?(part, file_to_find) end)
    end)
  end

  test "LIST", state do
    %{socket: socket, pasv_socket: pasv_socket} = setup_pasv_connection(state)

    # CWD w_dir
    w_dir = File.cwd!()
    :ok = :gen_tcp.send(socket, "CWD #{w_dir}\r\n")
    assert {:ok, "250 Directory changed successfully." <> _} = :gen_tcp.recv(socket, 0, 5_000)

    # LIST
    :ok = :gen_tcp.send(socket, "LIST\r\n")
    assert {:ok, "150 " <> _} = :gen_tcp.recv(socket, 0, 5_000)

    assert {:ok, listing} = read_fully(pasv_socket)

    assert {:ok, "226 Directory send OK." <> _} = :gen_tcp.recv(socket, 0, 5_000)

    parts = String.split(listing, "\r\n")
    refute Enum.empty?(parts)

    files_to_find = File.ls!(w_dir) |> Enum.reject(&String.starts_with?(&1, "."))
    refute Enum.empty?(files_to_find)

    Enum.each(files_to_find, fn file_to_find ->
      assert [_found] = Enum.filter(parts, fn part -> String.ends_with?(part, file_to_find) end)
    end)

    # LIST path
    %{socket: socket, pasv_socket: pasv_socket} = setup_pasv_connection(state)
    :ok = :gen_tcp.send(socket, "LIST #{w_dir}\r\n")
    assert {:ok, "150 " <> _} = :gen_tcp.recv(socket, 0, 5_000)
    # :ok, "226 Directory send OK.\r\n"}

    assert {:ok, listing} = read_fully(pasv_socket)

    assert {:ok, "226 Directory send OK." <> _} = :gen_tcp.recv(socket, 0, 5_000)

    parts = String.split(listing, "\r\n")
    refute Enum.empty?(parts)

    files_to_find = File.ls!(w_dir) |> Enum.reject(&String.starts_with?(&1, "."))
    refute Enum.empty?(files_to_find)

    Enum.each(files_to_find, fn file_to_find ->
      assert [_found] = Enum.filter(parts, fn part -> String.ends_with?(part, file_to_find) end)
    end)
  end

  test "NLST", state do
    %{socket: socket, pasv_socket: pasv_socket} = setup_pasv_connection(state)
    # CWD w_dir
    w_dir = File.cwd!()
    :ok = :gen_tcp.send(socket, "CWD #{w_dir}\r\n")
    assert {:ok, "250 Directory changed successfully." <> _} = :gen_tcp.recv(socket, 0, 5_000)

    # LIST
    :ok = :gen_tcp.send(socket, "NLST\r\n")
    assert {:ok, "150 " <> _} = :gen_tcp.recv(socket, 0, 5_000)

    assert {:ok, listing} = read_fully(pasv_socket)

    assert {:ok, "226 Directory send OK." <> _} = :gen_tcp.recv(socket, 0, 5_000)

    parts = String.split(listing, "\r\n")
    refute Enum.empty?(parts)

    files_to_find =
      File.ls!(w_dir) |> Enum.reject(&String.starts_with?(&1, ".")) |> Enum.sort()

    refute Enum.empty?(files_to_find)

    Enum.each(files_to_find, fn file_to_find ->
      assert [_found] = Enum.filter(parts, fn part -> String.starts_with?(part, file_to_find) end)
    end)
  end

  test "NLST -a", state do
    %{socket: socket, pasv_socket: pasv_socket} = setup_pasv_connection(state)
    # CWD w_dir
    w_dir = File.cwd!()
    :ok = :gen_tcp.send(socket, "CWD #{w_dir}\r\n")
    assert {:ok, "250 Directory changed successfully." <> _} = :gen_tcp.recv(socket, 0, 5_000)

    # LIST
    :ok = :gen_tcp.send(socket, "NLST -a\r\n")
    assert {:ok, "150 " <> _} = :gen_tcp.recv(socket, 0, 5_000)

    assert {:ok, listing} = read_fully(pasv_socket)

    assert {:ok, "226 Directory send OK." <> _} = :gen_tcp.recv(socket, 0, 5_000)

    parts = String.split(listing, "\r\n")
    refute Enum.empty?(parts)

    files_to_find =
      File.ls!(w_dir) |> Enum.sort()

    refute Enum.empty?(files_to_find)

    Enum.each(files_to_find, fn file_to_find ->
      assert [_found | _] =
               Enum.filter(parts, fn part -> String.starts_with?(part, file_to_find) end)
    end)
  end

  test "RETR", %{socket: socket, password: _password} = state do
    # CWD w_dir
    w_dir = File.cwd!()
    :ok = :gen_tcp.send(socket, "CWD #{w_dir}\r\n")
    assert {:ok, "250 Directory changed successfully." <> _} = :gen_tcp.recv(socket, 0, 5_000)

    files_to_download =
      File.ls!(w_dir) |> Enum.filter(fn file -> Path.join(w_dir, file) |> File.regular?() end)

    refute Enum.empty?(files_to_download)

    files_to_download
    |> Enum.each(fn file ->
      %{pasv_socket: pasv_socket} = setup_pasv_connection(state)
      :ok = :gen_tcp.send(socket, "RETR #{file}\r\n")
      assert {:ok, "150 " <> _} = :gen_tcp.recv(socket, 0, 10_000)
      assert {:ok, bytes} = read_fully(pasv_socket)
      refute byte_size(bytes) == 0
      assert bytes == File.read!(Path.join(w_dir, file)) <> "\r\n"
      assert {:ok, "226 Transfer complete." <> _} = :gen_tcp.recv(socket, 0, 10_000)
    end)
  end

  test "SIZE", %{socket: socket, password: _password} do
    # CWD w_dir
    w_dir = File.cwd!()
    :ok = :gen_tcp.send(socket, "CWD #{w_dir}\r\n")
    assert {:ok, "250 Directory changed successfully." <> _} = :gen_tcp.recv(socket, 0, 5_000)
    files_to_size = File.ls!(w_dir)
    refute Enum.empty?(files_to_size)

    files_to_size
    |> Enum.each(fn file ->
      :ok = :gen_tcp.send(socket, "SIZE #{file}\r\n")
      assert {:ok, "213 " <> size} = :gen_tcp.recv(socket, 0, 10_000)
      size = size |> String.trim() |> String.to_integer()
      assert %{size: ^size} = File.lstat!(Path.join(w_dir, file))
    end)
  end

  test "STOR", %{socket: socket, password: _password} = state do
    # CWD w_dir
    w_dir = System.tmp_dir!() |> Path.join("stor_test")
    :ok = File.mkdir_p!(w_dir)
    on_exit(fn -> File.rm_rf!(w_dir) end)
    :ok = :gen_tcp.send(socket, "CWD #{w_dir}\r\n")
    assert {:ok, "250 Directory changed successfully." <> _} = :gen_tcp.recv(socket, 0, 5_000)

    files_to_store =
      File.ls!(File.cwd!())
      |> Enum.filter(fn file -> Path.join(File.cwd!(), file) |> File.regular?() end)

    refute Enum.empty?(files_to_store)

    files_to_store
    |> Enum.each(fn file ->
      %{pasv_socket: pasv_socket} = setup_pasv_connection(state)
      :ok = :gen_tcp.send(socket, "STOR #{file}\r\n")
      assert {:ok, "150 " <> _} = :gen_tcp.recv(socket, 0, 10_000)

      File.stream!(Path.join(File.cwd!(), file), [], 5 * 1024 * 1024)
      |> Enum.each(fn data ->
        :ok = :gen_tcp.send(pasv_socket, data)
      end)

      :gen_tcp.close(pasv_socket)

      assert {:ok, "226 Transfer Complete.\r\n"} = :gen_tcp.recv(socket, 0, 30_000)

      :ok = :gen_tcp.send(socket, "SIZE #{file}\r\n")
      assert {:ok, "213 " <> size} = :gen_tcp.recv(socket, 0, 10_000)
      size = size |> String.trim() |> String.to_integer()
      assert %{size: ^size} = File.lstat!(Path.join(File.cwd!(), file))
    end)
  end

  defp read_fully(socket, data \\ <<>>) do
    case :gen_tcp.recv(socket, 0, 5_000) do
      {:ok, resp} -> read_fully(socket, data <> resp)
      {:error, :closed} -> {:ok, data}
    end
  end

  defp setup_pasv_connection(%{socket: socket} = state) do
    :ok = :gen_tcp.send(socket, "PASV\r\n")

    assert {:ok, "227 Entering Passive Mode " <> ip_port_string} =
             :gen_tcp.recv(socket, 0, 5_000)

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

    state
    |> Map.put(:pasv_socket, pasv_socket)
  end
end
