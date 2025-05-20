defmodule ExFTP.Auth.DigestAuthTest do
  @moduledoc false

  use ExUnit.Case

  alias ExFTP.Auth.DigestAuth

  doctest ExFTP.Auth.DigestAuth

  test "valid_user?/1" do
    assert DigestAuth.valid_user?(Faker.Internet.slug())
    assert DigestAuth.valid_user?("rOoT")
  end

  describe "login/2" do
    test "with config defined" do
      username = Faker.Internet.slug()
      password = Faker.Internet.slug()

      Application.put_env(:ex_ftp, :authenticator, ExFTP.Auth.DigestAuth)
      Application.put_env(:ex_ftp, :authenticator_config, %{
        login_url: "https://httpbin.dev/digest-auth/auth/#{username}/#{password}/MD5",
        login_method: :get
      })

      assert {:ok, _} = DigestAuth.login(password, %{username: username})

      Application.put_env(:ex_ftp, :authenticator, ExFTP.Auth.DigestAuth)
      Application.put_env(:ex_ftp, :authenticator_config, %{
        login_url: "https://httpbin.dev/status/404",
        login_method: :post
      })

      assert {:error, _} = DigestAuth.login(password, %{username: username})
    end

    test "without config defined" do
      Application.put_env(:ex_ftp, :authenticator, ExFTP.Auth.DigestAuth)
      Application.put_env(:ex_ftp, :authenticator_config, nil)

      assert {:error, _} =
               DigestAuth.login(Faker.Internet.slug(), %{username: Faker.Internet.slug()})
    end
  end

  describe "authenticated/1" do
    test "with custom authenticated route" do
      username = Faker.Internet.slug()
      password = Faker.Internet.slug()

      Application.put_env(:ex_ftp, :authenticator, ExFTP.Auth.DigestAuth)
      Application.put_env(:ex_ftp, :authenticator_config, %{
        login_url: "https://httpbin.dev/digest-auth/auth/#{username}/#{password}/MD5",
        login_method: :get,
        authenticated_url: "https://httpbin.dev/digest-auth/auth/#{username}/#{password}/MD5",
        authenticated_method: :get
      })

      assert {:ok, state} = DigestAuth.login(password, %{username: username})

      assert DigestAuth.authenticated?(state)

      Application.put_env(:ex_ftp, :authenticator, ExFTP.Auth.DigestAuth)
      Application.put_env(:ex_ftp, :authenticator_config, %{
        login_url: "https://httpbin.dev/digest-auth/auth/#{username}/#{password}/MD5",
        login_method: :get,
        authenticated_url: "https://httpbin.dev/post",
        authenticated_method: :get
      })

      refute DigestAuth.authenticated?(state)
    end

    test "without custom authenticated route" do
      username = Faker.Internet.slug()
      password = Faker.Internet.slug()

      Application.put_env(:ex_ftp, :authenticator, ExFTP.Auth.DigestAuth)
      Application.put_env(:ex_ftp, :authenticator_config, %{
        login_url: "https://httpbin.dev/digest-auth/auth/#{username}/#{password}/MD5",
        login_method: :get
      })

      assert DigestAuth.authenticated?(%{authenticated: true})
    end
  end
end
