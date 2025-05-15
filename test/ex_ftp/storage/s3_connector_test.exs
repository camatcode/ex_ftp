defmodule ExFTP.Storage.S3ConnectorTest do
  @moduledoc false

  use ExUnit.Case
  doctest ExFTP.Storage.S3Connector

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

    @tag run: true
    test "get_directory_contents/2" do
      bucket = "ex-ftp-test"
      state = %{current_working_directory: "/#{bucket}"}
      {:ok, state} = S3Connector.make_directory("/#{bucket}/my_dir", state)
      {:ok, state} = S3Connector.make_directory("/#{bucket}/my_dir/inner_dir", state)

      contents = S3Connector.get_directory_contents("/#{bucket}", state)

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

      contents =
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

      contents = S3Connector.get_directory_contents("/", state)

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

      contents =
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
  end
end
