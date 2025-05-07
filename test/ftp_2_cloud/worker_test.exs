defmodule FTP2Cloud.WorkerTest do
  @moduledoc false

  use ExUnit.Case

  setup do
    {:ok, socket} = :gen_tcp.connect({127, 0, 0, 1}, 4041, [:binary, active: false])
    {:ok, _} = :gen_tcp.recv(socket, 0, 10_000)

    on_exit(:close_socket, fn -> :gen_tcp.close(socket) end)

    %{socket: socket}
  end

  test "PWD", state do
    %{user: _user} = state = setup_user(state)

    %{socket: socket} = authenticate_user(state)

    :ok = :gen_tcp.send(socket, "PWD\r\n")

    {:ok, "257 \"/\" is the current directory\r\n"} =
      :gen_tcp.recv(socket, 0, 5_000)
  end

  defp authenticate_user(%{socket: socket, user: user, password: password} = state) do
    :ok = :gen_tcp.send(socket, "USER #{user.email}\r\n")
    assert {:ok, "331" <> _} = :gen_tcp.recv(socket, 0, 5_000)

    :ok = :gen_tcp.send(socket, "PASS #{password}\r\n")
    assert {:ok, "230" <> _} = :gen_tcp.recv(socket, 0, 5_000)

    state
  end

  defp authenticate_user(%{socket: socket} = state) do
    state = %{user: user, password: password} = setup_user(state)

    :ok = :gen_tcp.send(socket, "USER #{user.email}\r\n")
    assert {:ok, "331" <> _} = :gen_tcp.recv(socket, 0, 5_000)

    :ok = :gen_tcp.send(socket, "PASS #{password}\r\n")
    assert {:ok, "230" <> _} = :gen_tcp.recv(socket, 0, 5_000)

    state
  end

  defp setup_user(state) do
    {user, password} =
      {%{name: Faker.Internet.user_name(), email: Faker.Internet.email()},
       Faker.Internet.user_name()}

    state
    |> Map.put(:user, user)
    |> Map.put(:password, password)
  end
end
