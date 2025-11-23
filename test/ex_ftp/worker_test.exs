defmodule ExFTP.WorkerTest do
  use ExUnit.Case

  import ExFTP.TestHelper

  alias ExFTP.Auth.PassthroughAuth
  alias ExFTP.Storage.FileConnector

  doctest ExFTP.Worker
  @moduletag :capture_log
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

  test "authenticator_state is injected into connector_state after successful authentication", %{
    socket: existing_socket
  } do
    # Define a test connector that captures the connector_state
    defmodule TestAuthStateConnector do
      @behaviour ExFTP.StorageConnector

      @impl true
      def get_working_directory(connector_state) do
        # Send the connector_state to the test process
        Kernel.send(:test_process, {:connector_state, connector_state})
        connector_state.current_working_directory
      end

      @impl true
      def directory_exists?(_path, _connector_state), do: true

      @impl true
      def make_directory(_path, connector_state), do: {:ok, connector_state}

      @impl true
      def delete_directory(_path, connector_state), do: {:ok, connector_state}

      @impl true
      def delete_file(_path, connector_state), do: {:ok, connector_state}

      @impl true
      def get_directory_contents(_path, _connector_state), do: {:ok, []}

      @impl true
      def get_content_info(_path, _connector_state), do: {:error, :not_found}

      @impl true
      def get_content(_path, _connector_state), do: {:error, :not_found}

      @impl true
      def create_write_func(_path, connector_state, _opts) do
        fn _stream -> {:ok, connector_state} end
      end
    end

    # Register the test process
    Process.register(self(), :test_process)

    # Close the existing socket from setup
    :gen_tcp.close(existing_socket)
    :timer.sleep(100)

    # Configure the test connector
    Application.put_env(:ex_ftp, :storage_connector, TestAuthStateConnector)
    Application.put_env(:ex_ftp, :authenticator, PassthroughAuth)

    # Connect and authenticate
    socket = get_socket()
    username = "test_user"
    password = "test_pass"

    socket
    |> send_and_expect("USER", [username], 331, "User name okay, need password")
    |> send_and_expect("PASS", [password], 230, "Welcome.")
    |> send_and_expect("PWD", [], 257)

    # Verify that the connector received the authenticator_state
    assert_receive {:connector_state, connector_state}, 1000

    # Verify authenticator_state is present and contains correct data
    assert Map.has_key?(connector_state, :authenticator_state)
    assert connector_state.authenticator_state.username == username
    assert connector_state.authenticator_state.authenticated == true

    # Clean up
    :gen_tcp.close(socket)
  end
end
