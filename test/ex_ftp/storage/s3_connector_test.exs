defmodule ExFTP.Storage.S3ConnectorTest do
  @moduledoc false

  use ExUnit.Case
  doctest ExFTP.Storage.S3Connector

  import ExFTP.TestHelper

  alias ExFTP.Storage.S3Connector

  setup do
    Application.put_env(:ex_ftp, :authenticator, ExFTP.Auth.PassthroughAuth)
    Application.put_env(:ex_ftp, :storage_connector, ExFTP.Storage.S3Connector)
    Application.put_env(:ex_ftp, :storage_config, %{})
  end

  test "make_directory/2, delete_directory/2" do
    state = %{current_working_directory: "/"}
    {:ok, %{virtual_directories: v_dirs}} = S3Connector.make_directory("/my_dir", state)
    assert Enum.member?(v_dirs, "/")
    assert Enum.member?(v_dirs, "/my_dir")

    {:ok, %{virtual_directories: v_dirs}} = S3Connector.delete_directory("/my_dir", state)
    assert Enum.member?(v_dirs, "/")
    refute Enum.member?(v_dirs, "/my_dir")
  end

  describe "with no bucket in config" do
    setup do
      Application.put_env(:ex_ftp, :storage_config, %{})
    end

    test "directory_exists?/2" do
      state = %{}
      assert S3Connector.directory_exists?("/ex-ftp-test", state)
      refute S3Connector.directory_exists?("/does-not,exist", state)
    end

    test "get_directory_contents/2" do
      bucket = "ex-ftp-test"
      state = %{current_working_directory: "/#{bucket}"}
      {:ok, state} = S3Connector.make_directory("/#{bucket}/my_dir", state)
      {:ok, state} = S3Connector.make_directory("/#{bucket}/my_dir/inner_dir", state)

      {:ok, contents} = S3Connector.get_directory_contents("/#{bucket}", state)

      refute Enum.empty?(contents)

      expect = %{
        access: :read_write,
        size: 4096,
        type: :directory,
        file_name: "my_dir",
        modified_datetime: ~U[1970-01-01 00:00:00Z]
      }

      assert Enum.member?(contents, expect)

      dont_expect = Enum.filter(contents, &String.contains?(&1.file_name, "inner_dir"))
      assert Enum.empty?(dont_expect)

      {:ok, contents} =
        S3Connector.get_directory_contents("/#{bucket}/my_dir", state)

      expect = %{
        access: :read_write,
        size: 4096,
        type: :directory,
        file_name: "inner_dir",
        modified_datetime: ~U[1970-01-01 00:00:00Z]
      }

      assert Enum.member?(contents, expect)
    end

    test "get_content_info/2" do
      state = %{current_working_directory: "/ex-ftp-test"}

      {:ok, content} =
        S3Connector.get_content_info("/ex-ftp-test/README.md", state)

      assert content.file_name == "README.md"
    end

    test "get_content/2" do
      state = %{current_working_directory: "/"}

      {:ok, content} =
        S3Connector.get_content("/ex-ftp-test/README.md", state)

      on_exit(fn -> File.rm!("/tmp/README2.md") end)
      fd = File.stream!("/tmp/README2.md")

      content
      |> Enum.into(fd)

      bytes = File.read!("/tmp/README2.md")
      assert byte_size(bytes) != 0
    end

    @tag run: true
    test "get_write_func" do
      socket = get_socket()
      username = Faker.Internet.user_name()
      password = Faker.Internet.slug()

      send_and_expect(socket, "USER", [username], 331, "User name okay, need password")
      |> send_and_expect("PASS", [password], 230, "Welcome.")

      state = %{
        socket: socket,
        password: password,
        storage_connector: ExFTP.Storage.S3Connector,
        connector_state: %{current_working_directory: "/"}
      }

      # CWD w_dir
      w_dir = "/ex-ftp-test/write-test"

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
        # assert %{size: size} = File.lstat!(Path.join(File.cwd!(), file))
        # send_and_expect(socket, "SIZE", [file], 213, "#{size}")
      end)
    end
  end

  describe "with bucket in config" do
    setup do
      Application.put_env(:ex_ftp, :storage_config, %{storage_bucket: "ex-ftp-test"})
    end

    test "directory_exists?/2" do
      state = %{}
      assert S3Connector.directory_exists?("/", state)
      refute S3Connector.directory_exists?("/ex-ftp-test", state)
      refute S3Connector.directory_exists?("/does-not,exist", state)
    end

    test "get_directory_contents/2" do
      state = %{current_working_directory: "/"}

      {:ok, state} = S3Connector.make_directory("/my_dir", state)
      {:ok, state} = S3Connector.make_directory("/my_dir/inner_dir", state)

      {:ok, contents} = S3Connector.get_directory_contents("/", state)

      refute Enum.empty?(contents)

      expect = %{
        access: :read_write,
        size: 4096,
        type: :directory,
        file_name: "my_dir",
        modified_datetime: ~U[1970-01-01 00:00:00Z]
      }

      assert Enum.member?(contents, expect)

      dont_expect = Enum.filter(contents, &String.contains?(&1.file_name, "inner_dir"))
      assert Enum.empty?(dont_expect)

      {:ok, contents} =
        S3Connector.get_directory_contents("/my_dir", state)

      expect = %{
        access: :read_write,
        size: 4096,
        type: :directory,
        file_name: "inner_dir",
        modified_datetime: ~U[1970-01-01 00:00:00Z]
      }

      assert Enum.member?(contents, expect)
    end

    test "get_content_info" do
      state = %{current_working_directory: "/"}

      {:ok, content} =
        S3Connector.get_content_info("/README.md", state)

      assert content.file_name == "README.md"
    end

    test "get_content/2" do
      state = %{current_working_directory: "/"}

      {:ok, content} =
        S3Connector.get_content("/README.md", state)

      on_exit(fn -> File.rm!("/tmp/README.md") end)
      fd = File.stream!("/tmp/README.md")

      content
      |> Enum.into(fd)

      bytes = File.read!("/tmp/README.md")
      assert byte_size(bytes) != 0
    end
  end
end
