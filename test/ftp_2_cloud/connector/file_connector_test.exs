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

  test "PWD", %{socket: socket} do
    :ok = :gen_tcp.send(socket, "PWD\r\n")

    assert {:ok, "257 \"/\" is the current directory" <> _} =
             :gen_tcp.recv(socket, 0, 5_000)
  end
end
