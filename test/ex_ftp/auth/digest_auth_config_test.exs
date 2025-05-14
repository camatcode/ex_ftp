defmodule ExFTP.Auth.DigestAuthTest do
  @moduledoc false

  use ExUnit.Case

  alias ExFTP.Auth.DigestAuth

  import ExFTP.TestHelper

  doctest ExFTP.Auth.DigestAuth

  test "valid_user?/1" do
    assert DigestAuth.valid_user?(Faker.Internet.slug())
    assert DigestAuth.valid_user?("rOoT")
  end

  describe "login/2" do
    test "with config defined" do
      username = Faker.Internet.slug()
      password = Faker.Internet.slug()

      Application.put_env(:ex_ftp, :authenticator_config, %{
        login_url: "https://httpbin.dev/digest-auth/auth/#{username}/#{password}",
        login_method: :get
      })

      assert {:ok, _} = DigestAuth.login(password, %{username: username})

      Application.put_env(:ex_ftp, :authenticator_config, %{
        login_url: "https://httpbin.dev/status/401",
        login_method: :post
      })

      assert {:error, _} = DigestAuth.login(password, %{username: username})
    end

    test "without config defined" do
      Application.put_env(:ex_ftp, :authenticator_config, nil)

      assert {:error, _} =
               DigestAuth.login(Faker.Internet.slug(), %{username: Faker.Internet.slug()})
    end
  end

  describe "authenticated/1" do
    test "with custom authenticated route" do
      username = Faker.Internet.slug()
      password = Faker.Internet.slug()

      Application.put_env(:ex_ftp, :authenticator_config, %{
        login_url: "https://httpbin.dev/digest-auth/auth/#{username}/#{password}",
        login_method: :get,
        authenticated_url: "https://httpbin.dev/digest-auth/auth/#{username}/#{password}",
        authenticated_method: :get
      })

      assert {:ok, state} = DigestAuth.login(password, %{username: username})

      assert DigestAuth.authenticated?(state)

      Application.put_env(:ex_ftp, :authenticator_config, %{
        login_url: "https://httpbin.dev/digest-auth/auth/#{username}/#{password}",
        login_method: :get,
        authenticated_url: "https://httpbin.dev/post",
        authenticated_method: :get
      })

      refute DigestAuth.authenticated?(state)
    end

    test "without custom authenticated route" do
      username = Faker.Internet.slug()
      password = Faker.Internet.slug()

      Application.put_env(:ex_ftp, :authenticator_config, %{
        login_url: "https://httpbin.dev/digest-auth/auth/#{username}/#{password}",
        login_method: :get
      })

      assert DigestAuth.authenticated?(%{authenticated: true})
    end

    test "enforcing ttl" do
      socket = get_socket()
      username = Faker.Internet.slug()
      password = Faker.Internet.slug()

      Application.put_env(:ex_ftp, :authenticator_config, %{
        login_url: "https://httpbin.dev/digest-auth/auth/#{username}/#{password}",
        login_method: :get,
        authenticated_url: "https://httpbin.dev/digest-auth/auth/#{username}/#{password}",
        authenticated_method: :get,
        authenticated_ttl_ms: 1
      })

      send_and_expect(socket, "USER", [username], 331, "User name okay, need password")
      |> send_and_expect("PASS", [password], 230, "Welcome.")

      send_and_expect(socket, "PWD", [], 257, "\"/\" is the current directory")

      :timer.sleep(10)
      assert {:ok, false} = Cachex.exists?(:auth_cache, username)

      Application.put_env(:ex_ftp, :authenticator_config, %{
        login_url: "https://httpbin.dev/digest-auth/auth/#{username}/#{password}",
        login_method: :get,
        authenticated_url: "https://httpbin.dev/digest-auth/auth/#{username}/#{password}",
        authenticated_method: :get,
        authenticated_ttl_ms: 5000
      })

      send_and_expect(socket, "USER", [username], 331, "User name okay, need password")
      |> send_and_expect("PASS", [password], 230, "Welcome.")

      send_and_expect(socket, "PWD", [], 257, "\"/\" is the current directory")

      :timer.sleep(10)
      assert {:ok, true} = Cachex.exists?(:auth_cache, username)
    end
  end
end
