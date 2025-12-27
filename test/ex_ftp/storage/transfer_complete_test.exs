defmodule ExFTP.Storage.TransferCompleteTest do
  @moduledoc false

  use ExUnit.Case

  import ExFTP.StorageTester
  import ExFTP.TestHelper
  import ExUnit.CaptureLog

  alias ExFTP.Auth.PassthroughAuth
  alias ExFTP.Storage.FileConnector

  defmodule TestHandler do
    require Logger

    def handle_complete(type, path, _connector_state) do
      Logger.info("Custom handler called: #{type} #{path}")
      :ok
    end
  end

  describe "transfer completion with custom handler" do
    setup do
      Application.put_env(:ex_ftp, :authenticator, PassthroughAuth)
      Application.put_env(:ex_ftp, :authenticator_config, %{})
      Application.put_env(:ex_ftp, :storage_connector, FileConnector)

      Application.put_env(:ex_ftp, :storage_config, %{
        on_transfer_complete: {TestHandler, :handle_complete}
      })

      socket = get_socket()
      username = Faker.Internet.user_name()
      password = Faker.Internet.slug()

      socket
      |> send_and_expect("USER", [username], 331, "User name okay, need password")
      |> send_and_expect("PASS", [password], 230, "Welcome.")

      on_exit(fn ->
        Application.put_env(:ex_ftp, :storage_config, %{})
      end)

      %{socket: socket, username: username}
    end

    test "calls custom handler on STOR (upload)", state do
      w_dir = Path.join(System.tmp_dir!(), Faker.Internet.slug())
      on_exit(fn -> File.rm_rf!(w_dir) end)

      files_to_store =
        File.cwd!()
        |> File.ls!()
        |> Enum.filter(fn file -> File.cwd!() |> Path.join(file) |> File.regular?() end)
        |> Enum.take(1)

      refute Enum.empty?(files_to_store)

      log =
        capture_log(fn ->
          test_stor(state, w_dir, files_to_store)
        end)

      # Verify custom handler was called (not default)
      assert log =~ "Custom handler called: store"
      refute log =~ "Transfer complete: store"
    end

    test "calls custom handler on RETR (download)", state do
      w_dir = File.cwd!()

      paths_to_download =
        w_dir
        |> File.ls!()
        |> Enum.filter(fn file -> w_dir |> Path.join(file) |> File.regular?() end)
        |> Enum.take(1)

      refute Enum.empty?(paths_to_download)

      log =
        capture_log(fn ->
          test_retr(state, w_dir, paths_to_download)
        end)

      # Verify custom handler was called (not default)
      assert log =~ "Custom handler called: retrieve"
      refute log =~ "Transfer complete: retrieve"
    end
  end

  describe "transfer completion with default behavior" do
    setup do
      Application.put_env(:ex_ftp, :authenticator, PassthroughAuth)
      Application.put_env(:ex_ftp, :authenticator_config, %{})
      Application.put_env(:ex_ftp, :storage_connector, FileConnector)
      Application.put_env(:ex_ftp, :storage_config, %{})

      socket = get_socket()
      username = Faker.Internet.user_name()
      password = Faker.Internet.slug()

      socket
      |> send_and_expect("USER", [username], 331, "User name okay, need password")
      |> send_and_expect("PASS", [password], 230, "Welcome.")

      %{socket: socket}
    end

    test "logs default message on RETR when no handler configured", state do
      w_dir = File.cwd!()

      paths_to_download =
        w_dir
        |> File.ls!()
        |> Enum.filter(fn file -> w_dir |> Path.join(file) |> File.regular?() end)
        |> Enum.take(1)

      refute Enum.empty?(paths_to_download)

      log =
        capture_log(fn ->
          test_retr(state, w_dir, paths_to_download)
        end)

      # Verify default log message appears
      assert log =~ "Transfer complete: retrieve"
    end

    test "logs default message on STOR when no handler configured", state do
      w_dir = Path.join(System.tmp_dir!(), Faker.Internet.slug())
      on_exit(fn -> File.rm_rf!(w_dir) end)

      files_to_store =
        File.cwd!()
        |> File.ls!()
        |> Enum.filter(fn file -> File.cwd!() |> Path.join(file) |> File.regular?() end)
        |> Enum.take(1)

      refute Enum.empty?(files_to_store)

      log =
        capture_log(fn ->
          test_stor(state, w_dir, files_to_store)
        end)

      # Verify default log message appears
      assert log =~ "Transfer complete: store"
    end
  end
end
