defmodule FTP2Cloud.Connector.FileConnectorTest do
  @moduledoc false

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

    {:ok, "550 Requested action not taken. File unavailable." <> _} =
      :gen_tcp.recv(socket, 0, 5_000)
  end

  test "CWD/CDUP", %{socket: socket, password: _password} do
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

  test "MKD", %{socket: socket, password: _password} do
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
  end
end
