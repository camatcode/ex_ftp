defmodule ExFTP.Storage.FileConnectorTest do
  @moduledoc false

  import ExFTP.TestHelper

  use ExUnit.Case
  doctest ExFTP.Storage.FileConnector

  setup do
    Application.put_env(:ex_ftp, :authenticator, ExFTP.Auth.PassthroughAuth)
    {:ok, socket} = :gen_tcp.connect({127, 0, 0, 1}, 4041, [:binary, active: false])
    {:ok, _} = :gen_tcp.recv(socket, 0, 10_000)

    on_exit(:close_socket, fn -> :gen_tcp.close(socket) end)

    username = Faker.Internet.user_name()
    password = Faker.Internet.slug()

    send_and_expect(socket, "USER", [username], 331, "User name okay, need password")
    |> send_and_expect("PASS", [password], 230, "Welcome.")

    %{socket: socket, username: username, password: password}
  end

  test "PWD", %{socket: socket, password: password} do
    send_and_expect(socket, "PWD", [], 257, "\"/\" is the current directory")

    # root can't PWD with passthrough auth
    send_and_expect(socket, "USER", ["root"], 331, "User name okay, need password")
    |> send_and_expect("PASS", [password], 530, "Authentication failed.")
    |> send_and_expect("PWD", [], 530, "Not logged in")
  end

  test "CWD / CDUP", %{socket: socket, password: _password} do
    # PWD
    send_and_expect(socket, "PWD", [], 257, "\"/\" is the current directory")

    # CWD tmp_dir
    # PWD
    # CDUP
    # CDUP
    tmp_dir = System.tmp_dir!()

    socket
    |> send_and_expect("CWD", [tmp_dir], 250, "Directory changed successfully.")
    |> send_and_expect("PWD", [], 257, "\"#{tmp_dir}\" is the current directory")
    |> send_and_expect("CDUP", [], 250, "Directory changed successfully.")
    |> send_and_expect("CDUP", [], 250, "Directory changed successfully.")
    |> send_and_expect("PWD", [], 257, "\"/\" is the current directory")

    # CWD does-not-exist
    # PWD
    socket
    |> send_and_expect(
      "CWD",
      ["does-not-exist"],
      550,
      "Failed to change directory. Does not exist."
    )
    |> send_and_expect("PWD", [], 257, "\"/\" is the current directory")
  end

  test "MKD / RMD", %{socket: socket, password: _password} do
    # PWD
    send_and_expect(socket, "PWD", [], 257, "\"/\" is the current directory")

    tmp_dir = System.tmp_dir!()
    dir_to_make = Path.join(tmp_dir, Faker.Internet.slug())
    refute File.exists?(dir_to_make)
    on_exit(fn -> File.rm_rf!(dir_to_make) end)

    # CWD tmp_dir
    # MKD dir_to_make
    socket
    |> send_and_expect("CWD", [tmp_dir], 250, "Directory changed successfully.")
    |> send_and_expect("MKD", [dir_to_make], 257, "\"#{dir_to_make}\" directory created.")

    assert File.exists?(dir_to_make)

    # CWD dir_to_make
    # RMD dir_to_make
    socket
    |> send_and_expect("CWD", [dir_to_make], 250, "Directory changed successfully.")
    |> send_and_expect("RMD", [dir_to_make], 250, "\"#{dir_to_make}\" directory removed.")

    refute File.exists?(dir_to_make)

    # verify you've been kicked out
    # PWD
    socket
    |> send_and_expect("PWD", [], 257, "\"#{tmp_dir}\" is the current directory")
  end

  test "LIST -a", state do
    %{socket: socket, pasv_socket: pasv_socket} = setup_pasv_connection(state)

    # CWD w_dir
    w_dir = File.cwd!()

    socket
    |> send_and_expect("CWD", [w_dir], 250, "Directory changed successfully.")
    |> send_and_expect("LIST", ["-a"], 150)

    assert {:ok, listing} = read_fully(pasv_socket)

    expect_recv(socket, 226, "Directory send OK.")

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

    socket
    |> send_and_expect("CWD", [w_dir], 250, "Directory changed successfully.")
    |> send_and_expect("LIST", [], 150)

    assert {:ok, listing} = read_fully(pasv_socket)

    expect_recv(socket, 226, "Directory send OK.")

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

    socket
    |> send_and_expect("CWD", [w_dir], 250, "Directory changed successfully.")
    |> send_and_expect("NLST", [], 150)

    assert {:ok, listing} = read_fully(pasv_socket)

    expect_recv(socket, 226, "Directory send OK.")

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

    socket
    |> send_and_expect("CWD", [w_dir], 250, "Directory changed successfully.")
    |> send_and_expect("NLST", ["-a"], 150)

    assert {:ok, listing} = read_fully(pasv_socket)

    expect_recv(socket, 226, "Directory send OK.")

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

    socket
    |> send_and_expect("CWD", [w_dir], 250, "Directory changed successfully.")

    files_to_download =
      File.ls!(w_dir) |> Enum.filter(fn file -> Path.join(w_dir, file) |> File.regular?() end)

    refute Enum.empty?(files_to_download)

    files_to_download
    |> Enum.each(fn file ->
      %{pasv_socket: pasv_socket} = setup_pasv_connection(state)
      send_and_expect(socket, "RETR", [file], 150)
      assert {:ok, bytes} = read_fully(pasv_socket)
      refute byte_size(bytes) == 0
      assert bytes == File.read!(Path.join(w_dir, file)) <> "\r\n"
      expect_recv(socket, 226, "Transfer complete.")
    end)
  end

  test "SIZE", %{socket: socket, password: _password} do
    # CWD w_dir
    w_dir = File.cwd!()

    socket
    |> send_and_expect("CWD", [w_dir], 250, "Directory changed successfully.")

    files_to_size = File.ls!(w_dir)
    refute Enum.empty?(files_to_size)

    files_to_size
    |> Enum.each(fn file ->
      assert %{size: size} = File.lstat!(Path.join(w_dir, file))
      send_and_expect(socket, "SIZE", [file], 213, "#{size}")
    end)
  end

  test "STOR", %{socket: socket, password: _password} = state do
    # CWD w_dir
    w_dir = System.tmp_dir!() |> Path.join("stor_test")
    on_exit(fn -> File.rm_rf!(w_dir) end)

    socket
    |> send_and_expect("MKD", [w_dir], 257, "\"#{w_dir}\" directory created.")
    |> send_and_expect("CWD", [w_dir], 250, "Directory changed successfully.")

    files_to_store =
      File.ls!(File.cwd!())
      |> Enum.filter(fn file -> Path.join(File.cwd!(), file) |> File.regular?() end)

    refute Enum.empty?(files_to_store)

    files_to_store
    |> Enum.each(fn file ->
      %{pasv_socket: pasv_socket} = setup_pasv_connection(state)
      send_and_expect(socket, "STOR", [file], 150)

      File.stream!(Path.join(File.cwd!(), file), [], 5 * 1024 * 1024)
      |> Enum.each(fn data ->
        :ok = :gen_tcp.send(pasv_socket, data)
      end)

      close_pasv(pasv_socket)

      expect_recv(socket, 226, "Transfer Complete.")
      assert %{size: size} = File.lstat!(Path.join(File.cwd!(), file))
      send_and_expect(socket, "SIZE", [file], 213, "#{size}")
    end)
  end
end
