defmodule ExFTP.Storage.FileConnectorTest do
  @moduledoc false

  use ExUnit.Case

  import ExFTP.StorageTester
  import ExFTP.TestHelper

  alias ExFTP.Auth.PassthroughAuth
  alias ExFTP.Storage.Common
  alias ExFTP.Storage.FileConnector

  doctest Common
  doctest FileConnector

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

  test "PWD", %{socket: socket, password: password} = state do
    test_pwd(state)

    # root can't PWD with passthrough auth
    socket
    |> send_and_expect("USER", ["root"], 331, "User name okay, need password")
    |> send_and_expect("PASS", [password], 530, "Authentication failed.")
    |> send_and_expect("PWD", [], 530, "Not logged in")
  end

  test "CWD / CDUP", state do
    tmp_dir = Path.join(System.tmp_dir!(), Faker.Internet.slug())
    on_exit(fn -> File.rm_rf(tmp_dir) end)
    test_cwd_cdup(state, tmp_dir)
  end

  test "MKD / RMD", state do
    tmp_dir = Path.join(System.tmp_dir!(), Faker.Internet.slug())
    on_exit(fn -> File.rm_rf(tmp_dir) end)
    test_mkd_rmd(state, tmp_dir)
  end

  test "LIST -a", state do
    w_dir = File.cwd!()
    listing = test_list_a(state, w_dir)

    parts = String.split(listing, "\r\n")
    refute Enum.empty?(parts)

    files_to_find = File.ls!(w_dir)
    refute Enum.empty?(files_to_find)

    Enum.each(files_to_find, fn file_to_find ->
      assert [_found] = Enum.filter(parts, fn part -> String.ends_with?(part, file_to_find) end)
    end)
  end

  test "LIST", state do
    w_dir = File.cwd!()
    listing = test_list(state, w_dir)

    parts = String.split(listing, "\r\n")
    refute Enum.empty?(parts)

    files_to_find = w_dir |> File.ls!() |> Enum.reject(&String.starts_with?(&1, "."))
    refute Enum.empty?(files_to_find)

    Enum.each(files_to_find, fn file_to_find ->
      assert [_found] = Enum.filter(parts, fn part -> String.ends_with?(part, file_to_find) end)
    end)
  end

  test "DELE", state do
    # CWD w_dir
    w_dir = Path.join(System.tmp_dir!(), Faker.Internet.slug())
    on_exit(fn -> File.rm_rf!(w_dir) end)

    files_to_store =
      File.cwd!()
      |> File.ls!()
      |> Enum.filter(fn file -> File.cwd!() |> Path.join(file) |> File.regular?() end)

    refute Enum.empty?(files_to_store)

    test_dele(state, w_dir, files_to_store)
  end

  test "NLST", state do
    w_dir = File.cwd!()
    listing = test_nlst(state, w_dir)

    parts = String.split(listing, "\r\n")
    refute Enum.empty?(parts)

    files_to_find =
      w_dir |> File.ls!() |> Enum.reject(&String.starts_with?(&1, ".")) |> Enum.sort()

    refute Enum.empty?(files_to_find)

    Enum.each(files_to_find, fn file_to_find ->
      assert [_found | _] = Enum.filter(parts, fn part -> String.starts_with?(part, file_to_find) end)
    end)
  end

  test "NLST -a", state do
    w_dir = File.cwd!()

    listing = test_nlst_a(state, w_dir)

    parts = String.split(listing, "\r\n")
    refute Enum.empty?(parts)

    files_to_find =
      w_dir |> File.ls!() |> Enum.sort()

    refute Enum.empty?(files_to_find)

    Enum.each(files_to_find, fn file_to_find ->
      assert [_found | _] =
               Enum.filter(parts, fn part -> String.starts_with?(part, file_to_find) end)
    end)
  end

  test "RETR", state do
    # CWD w_dir
    w_dir = File.cwd!()

    paths_to_download =
      w_dir |> File.ls!() |> Enum.filter(fn file -> w_dir |> Path.join(file) |> File.regular?() end)

    test_retr(state, w_dir, paths_to_download)
  end

  test "SIZE", state do
    # CWD w_dir
    w_dir = File.cwd!()
    test_size(state, w_dir)
  end

  test "STOR", state do
    # CWD w_dir
    w_dir = Path.join(System.tmp_dir!(), Faker.Internet.slug())
    on_exit(fn -> File.rm_rf!(w_dir) end)

    files_to_store =
      File.cwd!()
      |> File.ls!()
      |> Enum.filter(fn file -> File.cwd!() |> Path.join(file) |> File.regular?() end)

    refute Enum.empty?(files_to_store)

    test_stor(state, w_dir, files_to_store)
  end
end
