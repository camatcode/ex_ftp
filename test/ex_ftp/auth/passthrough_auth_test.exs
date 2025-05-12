defmodule ExFTP.Auth.PassthroughAuthTest do
  @moduledoc false

  use ExUnit.Case
  doctest ExFTP.Auth.PassthroughAuth

  import ExFTP.TestHelper

  setup do
    Application.put_env(:ex_ftp, :authenticator, ExFTP.Auth.PassthroughAuth)
    {:ok, socket} = :gen_tcp.connect({127, 0, 0, 1}, 4041, [:binary, active: false])
    {:ok, _} = :gen_tcp.recv(socket, 0, 10_000)

    on_exit(:close_socket, fn -> :gen_tcp.close(socket) end)

    %{socket: socket}
  end

  test "USER", %{socket: socket} do
    username = Faker.Internet.user_name()
    send_and_expect(socket, "USER", [username], 331, "User name okay, need password")
  end

  test "PASS", %{socket: socket} do
    username = Faker.Internet.user_name()
    password = Faker.Internet.slug()

    # test deny root
    socket
    |> send_and_expect("USER", ["root"], 331, "User name okay, need password")
    |> send_and_expect("PASS", [password], 530, "Authentication failed.")

    # passthrough auth allows any user (except "root") and blindly accepts any password
    socket
    |> send_and_expect("USER", [username], 331, "User name okay, need password")
    |> send_and_expect("PASS", [password], 230, "Welcome.")
  end
end
