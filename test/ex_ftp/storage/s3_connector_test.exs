defmodule ExFTP.Storage.S3ConnectorTest do
  @moduledoc false

  use ExUnit.Case

  import ExFTP.StorageTester
  import ExFTP.TestHelper

  alias ExFTP.Auth.PassthroughAuth
  alias ExFTP.Storage.S3Connector

  @moduletag :capture_log
  doctest S3Connector

  setup do
    Application.put_env(:ex_ftp, :authenticator, PassthroughAuth)
    Application.put_env(:ex_ftp, :storage_connector, S3Connector)
    Application.put_env(:ex_ftp, :storage_config, %{storage_bucket: "ex-ftp-test"})

    socket = get_socket()
    username = Faker.Internet.user_name()
    password = Faker.Internet.slug()

    socket
    |> send_and_expect("USER", [username], 331, "User name okay, need password")
    |> send_and_expect("PASS", [password], 230, "Welcome.")

    %{
      socket: socket,
      password: password,
      storage_connector: S3Connector,
      connector_state: %{current_working_directory: "/"}
    }
  end

  test "PWD", state do
    test_pwd(state)
  end

  test "CWD / CDUP", state do
    tmp_dir = Path.join("/", Faker.Internet.slug())
    on_exit(fn -> S3Connector.delete_directory(tmp_dir, %{current_working_directory: "/"}) end)
    test_cwd_cdup(state, tmp_dir)
  end

  test "MKD / RMD", state do
    tmp_dir = Path.join("/", Faker.Internet.slug())
    on_exit(fn -> S3Connector.delete_directory(tmp_dir, %{current_working_directory: "/"}) end)
    test_mkd_rmd(state, tmp_dir)
  end

  test "LIST -a, LIST, NLST, NLST -a, STOR, SIZE, RETR, DELE", state do
    tmp_dir = Path.join("/", Faker.Internet.slug())
    on_exit(fn -> S3Connector.delete_directory(tmp_dir, %{current_working_directory: "/"}) end)

    files_to_store =
      File.cwd!()
      |> File.ls!()
      |> Enum.filter(fn file -> File.cwd!() |> Path.join(file) |> File.regular?() end)

    refute Enum.empty?(files_to_store)

    test_stor(state, tmp_dir, files_to_store)

    # LIST -a
    listing = test_list_a(state, tmp_dir)

    parts = String.split(listing, "\r\n")
    refute Enum.empty?(parts)

    files_to_find =
      File.cwd!()
      |> File.ls!()
      |> Enum.filter(fn file -> File.cwd!() |> Path.join(file) |> File.regular?() end)

    refute Enum.empty?(files_to_find)

    Enum.each(files_to_find, fn file_to_find ->
      assert [_found] = Enum.filter(parts, fn part -> String.ends_with?(part, file_to_find) end)
    end)

    # LIST
    test_list(state, tmp_dir)

    parts = String.split(listing, "\r\n")
    refute Enum.empty?(parts)

    files_to_find =
      File.cwd!()
      |> File.ls!()
      |> Enum.filter(fn file -> File.cwd!() |> Path.join(file) |> File.regular?() end)
      |> Enum.reject(&String.starts_with?(&1, "."))

    refute Enum.empty?(files_to_find)

    Enum.each(files_to_find, fn file_to_find ->
      assert [_found] = Enum.filter(parts, fn part -> String.ends_with?(part, file_to_find) end)
    end)

    # NLST
    listing = test_nlst(state, tmp_dir)

    parts = String.split(listing, "\r\n")
    refute Enum.empty?(parts)

    files_to_find =
      File.cwd!()
      |> File.ls!()
      |> Enum.filter(fn file -> File.cwd!() |> Path.join(file) |> File.regular?() end)
      |> Enum.reject(&String.starts_with?(&1, "."))
      |> Enum.sort()

    refute Enum.empty?(files_to_find)

    Enum.each(files_to_find, fn file_to_find ->
      assert [_found] = Enum.filter(parts, fn part -> String.starts_with?(part, file_to_find) end)
    end)

    # NLST -a

    listing = test_nlst_a(state, tmp_dir)

    parts = String.split(listing, "\r\n")
    refute Enum.empty?(parts)

    files_to_find =
      File.cwd!()
      |> File.ls!()
      |> Enum.filter(fn file -> File.cwd!() |> Path.join(file) |> File.regular?() end)
      |> Enum.sort()

    refute Enum.empty?(files_to_find)

    Enum.each(files_to_find, fn file_to_find ->
      assert [_found | _] =
               Enum.filter(parts, fn part -> String.starts_with?(part, file_to_find) end)
    end)

    # SIZE
    :timer.sleep(100)
    test_size(state, tmp_dir)

    # RETR
    paths_to_download =
      File.cwd!()
      |> File.ls!()
      |> Enum.filter(fn file -> File.cwd!() |> Path.join(file) |> File.regular?() end)

    test_retr(state, tmp_dir, paths_to_download)

    # DELE
    tmp_dir = Path.join("/", Faker.Internet.slug())
    test_dele(state, tmp_dir, files_to_store)
  end
end
