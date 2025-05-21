defmodule ExFTP.WorkerTest do
  use ExUnit.Case

  import ExFTP.TestHelper

  alias ExFTP.Auth.PassthroughAuth
  alias ExFTP.Storage.FileConnector

  doctest ExFTP.Worker

  setup do
    Application.put_env(:ex_ftp, :authenticator, PassthroughAuth)
    Application.put_env(:ex_ftp, :storage_connector, FileConnector)
    Application.put_env(:ex_ftp, :storage_config, %{})

    socket = get_socket()
    username = Faker.Internet.user_name()
    password = Faker.Internet.slug()

    socket
    |> send_and_expect("USER", [username], 331, "User name okay, need password")
    |> send_and_expect("PASS", [password], 230, "Welcome.")

    %{
      socket: socket,
      password: password,
      storage_connector: FileConnector,
      connector_state: %{current_working_directory: "/"}
    }
  end

  test "quit", %{socket: socket} do
    send_and_expect(socket, "QUIT", [], 221)
  end

  test "syst", %{socket: socket} do
    send_and_expect(socket, "SYST", [], 215)
  end

  test "type", %{socket: socket} do
    send_and_expect(socket, "TYPE", ["I"], 200)
    |> send_and_expect("TYPE", ["A"], 200)
    |> send_and_expect("TYPE", ["X"], 504)
  end

  test "epsv/eprt", %{socket: socket} do
    send_and_expect(socket, "EPSV", [], 229)
    |> send_and_expect("EPRT", ["123"], 200)
  end

  test "not implemented", %{socket: socket} do
    send_and_expect(socket, "CUSTOM", [], 502)
  end
end
