defmodule ExFTP.Auth.BasicAuthTest do
  @moduledoc false

  use ExUnit.Case

  import ExFTP.TestHelper

  alias ExFTP.Auth.BasicAuth

  doctest BasicAuth

  @moduletag :capture_log

  test "valid_user?/1" do
    assert BasicAuth.valid_user?(Faker.Internet.slug())
    assert BasicAuth.valid_user?("rOoT")
  end

  describe "login/2" do
    test "with config defined" do
      username = Faker.Internet.slug()
      password = Faker.Internet.slug()

      Application.put_env(:ex_ftp, :authenticator, BasicAuth)

      Application.put_env(:ex_ftp, :authenticator_config, %{
        login_url: "https://httpbin.dev/basic-auth/#{username}/#{password}",
        login_method: :get
      })

      assert {:ok, _} = BasicAuth.login(password, %{username: username})

      Application.put_env(:ex_ftp, :authenticator, BasicAuth)

      Application.put_env(:ex_ftp, :authenticator_config, %{
        login_url: "https://httpbin.dev/status/401",
        login_method: :post,
        password_hash_type: :sha256
      })

      assert {:error, _} =
               BasicAuth.login(Faker.Internet.slug(), %{username: Faker.Internet.slug()})
    end

    test "without config defined" do
      Application.put_env(:ex_ftp, :authenticator, BasicAuth)
      Application.put_env(:ex_ftp, :authenticator_config, nil)

      assert {:error, _} =
               BasicAuth.login(Faker.Internet.slug(), %{username: Faker.Internet.slug()})
    end
  end

  describe "authenticated/1" do
    test "no inputs" do
      Application.put_env(:ex_ftp, :authenticator, BasicAuth)

      Application.put_env(:ex_ftp, :authenticator_config, %{
        login_url: "",
        login_method: :get,
        authenticated_url: "",
        authenticated_method: :get
      })

      refute BasicAuth.authenticated?(%{})

      Application.put_env(:ex_ftp, :authenticator_config, %{})

      refute BasicAuth.authenticated?(%{})
    end

    test "with custom authenticated route" do
      username = Faker.Internet.slug()
      password = Faker.Internet.slug()

      Application.put_env(:ex_ftp, :authenticator, BasicAuth)

      Application.put_env(:ex_ftp, :authenticator_config, %{
        login_url: "https://httpbin.dev/basic-auth/#{username}/#{password}",
        login_method: :get,
        authenticated_url: "https://httpbin.dev/basic-auth/#{username}/#{password}",
        authenticated_method: :get
      })

      assert {:ok, state} = BasicAuth.login(password, %{username: username})

      assert BasicAuth.authenticated?(state)

      Application.put_env(:ex_ftp, :authenticator, BasicAuth)

      Application.put_env(:ex_ftp, :authenticator_config, %{
        login_url: "https://httpbin.dev/basic-auth/#{username}/#{password}",
        login_method: :get,
        authenticated_url: "https://httpbin.dev/basic-auth/not-#{username}/#{password}",
        authenticated_method: :get
      })

      refute BasicAuth.authenticated?(state)
    end

    test "without custom authenticated route" do
      Application.put_env(:ex_ftp, :authenticator, BasicAuth)

      Application.put_env(:ex_ftp, :authenticator_config, %{
        login_url: "https://httpbin.dev/get",
        login_method: :get
      })

      assert BasicAuth.authenticated?(%{authenticated: true})
    end

    test "enforcing ttl" do
      username = Faker.Internet.slug()
      password = Faker.Internet.slug()

      Application.put_env(:ex_ftp, :authenticator, BasicAuth)

      Application.put_env(:ex_ftp, :authenticator_config, %{
        login_url: "https://httpbin.dev/basic-auth/#{username}/#{password}",
        login_method: :get,
        authenticated_url: "https://httpbin.dev/basic-auth/#{username}/#{password}",
        authenticated_method: :get,
        authenticated_ttl_ms: 1
      })

      socket = get_socket()

      socket
      |> send_and_expect("USER", [username], 331, "User name okay, need password")
      |> send_and_expect("PASS", [password], 230, "Welcome.")

      send_and_expect(socket, "PWD", [], 257, "\"/\" is the current directory")

      :timer.sleep(10)
      assert {:ok, false} = Cachex.exists?(:auth_cache, username)

      Application.put_env(:ex_ftp, :authenticator, BasicAuth)

      Application.put_env(:ex_ftp, :authenticator_config, %{
        login_url: "https://httpbin.dev/basic-auth/#{username}/#{password}",
        login_method: :get,
        authenticated_url: "https://httpbin.dev/basic-auth/#{username}/#{password}",
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
end
