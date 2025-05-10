defmodule ExFTP.Auth.PassthroughAuthTest do
  @moduledoc false

  use ExUnit.Case
  doctest ExFTP.Auth.PassthroughAuth

  setup do
    Application.put_env(:ex_ftp, :authenticator, ExFTP.Auth.PassthroughAuth)
    {:ok, socket} = :gen_tcp.connect({127, 0, 0, 1}, 4041, [:binary, active: false])
    {:ok, _} = :gen_tcp.recv(socket, 0, 10_000)

    on_exit(:close_socket, fn -> :gen_tcp.close(socket) end)

    %{socket: socket}
  end

  test "USER", %{socket: socket} do
    username = Faker.Internet.user_name()
    :ok = :gen_tcp.send(socket, "USER #{username}\r\n")
    assert {:ok, "331 User name okay, need password" <> _} = :gen_tcp.recv(socket, 0, 5_000)
  end

  test "PASS", %{socket: socket} do
    username = Faker.Internet.user_name()
    password = Faker.Internet.slug()

    # passthrough auth allows any user (except "root") and blindly accepts any password
    :ok = :gen_tcp.send(socket, "USER #{username}\r\n")
    assert {:ok, "331 User name okay, need password" <> _} = :gen_tcp.recv(socket, 0, 5_000)

    :ok = :gen_tcp.send(socket, "PASS #{password}\r\n")
    match = "230 Welcome."
    assert {:ok, ^match <> _} = :gen_tcp.recv(socket, 0, 5_000)

    # test deny root
    :ok = :gen_tcp.send(socket, "USER root\r\n")
    assert {:ok, "331 User name okay, need password" <> _} = :gen_tcp.recv(socket, 0, 5_000)

    :ok = :gen_tcp.send(socket, "PASS #{password}\r\n")
    match = "530 Authentication failed."
    assert {:ok, ^match <> _} = :gen_tcp.recv(socket, 0, 5_000)
  end
end
