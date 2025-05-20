defmodule ExFTP.Auth.IsolatedTest do
  @moduledoc false

  use ExUnit.Case

  import ExFTP.TestHelper

  alias ExFTP.Auth.DigestAuth

  # I don't understand why, but putting this with all the other digest tests causes a failure when in suite
  test "enforcing ttl" do
    socket = get_socket()
    username = Faker.Internet.user_name()
    password = Faker.Internet.slug()

    Application.put_env(:ex_ftp, :authenticator, DigestAuth)

    Application.put_env(:ex_ftp, :authenticator_config, %{
      login_url: "https://httpbin.dev/digest-auth/auth/#{username}/#{password}/MD5",
      login_method: :get,
      authenticated_url: "https://httpbin.dev/digest-auth/auth/#{username}/#{password}/MD5",
      authenticated_method: :get,
      authenticated_ttl_ms: 1
    })

    socket
    |> send_and_expect("USER", [username], 331, "User name okay, need password")
    |> send_and_expect("PASS", [password], 230, "Welcome.")

    send_and_expect(socket, "PWD", [], 257, "\"/\" is the current directory")

    :timer.sleep(10)
    assert {:ok, false} = Cachex.exists?(:auth_cache, username)

    Application.put_env(:ex_ftp, :authenticator, DigestAuth)

    Application.put_env(:ex_ftp, :authenticator_config, %{
      login_url: "https://httpbin.dev/digest-auth/auth/#{username}/#{password}/MD5",
      login_method: :get,
      authenticated_url: "https://httpbin.dev/digest-auth/auth/#{username}/#{password}/MD5",
      authenticated_method: :get,
      authenticated_ttl_ms: 5000
    })

    socket
    |> send_and_expect("USER", [username], 331, "User name okay, need password")
    |> send_and_expect("PASS", [password], 230, "Welcome.")

    send_and_expect(socket, "PWD", [], 257, "\"/\" is the current directory")

    :timer.sleep(10)
    assert {:ok, true} = Cachex.exists?(:auth_cache, username)
  end
end
