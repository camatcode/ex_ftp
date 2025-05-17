defmodule ExFTP.Auth.WebhookAuthTest do
  @moduledoc false

  use ExUnit.Case

  import ExFTP.TestHelper

  alias ExFTP.Auth.WebhookAuth

  doctest ExFTP.Auth.WebhookAuth

  test "valid_user?/1" do
    assert WebhookAuth.valid_user?(Faker.Internet.slug())
    assert WebhookAuth.valid_user?("rOoT")
  end

  describe "login/2" do
    test "with config defined" do
      Application.put_env(:ex_ftp, :authenticator_config, %{
        login_url: "https://httpbin.dev/get",
        login_method: :get
      })

      assert {:ok, _} =
               WebhookAuth.login(Faker.Internet.slug(), %{username: Faker.Internet.slug()})

      Application.put_env(:ex_ftp, :authenticator_config, %{
        login_url: "https://httpbin.dev/status/401",
        login_method: :post,
        password_hash_type: :sha256
      })

      assert {:error, _} =
               WebhookAuth.login(Faker.Internet.slug(), %{username: Faker.Internet.slug()})
    end

    test "without config defined" do
      Application.put_env(:ex_ftp, :authenticator_config, nil)

      assert {:error, _} =
               WebhookAuth.login(Faker.Internet.slug(), %{username: Faker.Internet.slug()})
    end
  end

  describe "authenticated/1" do
    test "with custom authenticated route" do
      Application.put_env(:ex_ftp, :authenticator_config, %{
        login_url: "https://httpbin.dev/get",
        login_method: :get,
        authenticated_url: "https://httpbin.dev/get",
        authenticated_method: :get
      })

      assert WebhookAuth.authenticated?(%{username: Faker.Internet.slug()})

      Application.put_env(:ex_ftp, :authenticator_config, %{
        login_url: "https://httpbin.dev/get",
        login_method: :get,
        authenticated_url: "https://httpbin.dev/post",
        authenticated_method: :get
      })

      refute WebhookAuth.authenticated?(%{username: Faker.Internet.slug()})
    end

    test "without custom authenticated route" do
      Application.put_env(:ex_ftp, :authenticator_config, %{
        login_url: "https://httpbin.dev/get",
        login_method: :get
      })

      assert WebhookAuth.authenticated?(%{authenticated: true})
    end

    test "enforcing ttl" do
      Application.put_env(:ex_ftp, :authenticator_config, %{
        login_url: "https://httpbin.dev/get",
        login_method: :get,
        authenticated_url: "https://httpbin.dev/get",
        authenticated_method: :get,
        authenticated_ttl_ms: 1
      })

      socket = get_socket()
      username = Faker.Internet.slug()
      password = Faker.Internet.slug()

      socket
      |> send_and_expect("USER", [username], 331, "User name okay, need password")
      |> send_and_expect("PASS", [password], 230, "Welcome.")

      send_and_expect(socket, "PWD", [], 257, "\"/\" is the current directory")

      :timer.sleep(10)
      assert {:ok, false} = Cachex.exists?(:auth_cache, username)

      Application.put_env(:ex_ftp, :authenticator_config, %{
        login_url: "https://httpbin.dev/get",
        login_method: :get,
        authenticated_url: "https://httpbin.dev/get",
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
