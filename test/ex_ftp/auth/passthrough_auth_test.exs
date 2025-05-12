defmodule ExFTP.Auth.PassthroughAuthTest do
  @moduledoc false

  use ExUnit.Case

  alias ExFTP.Auth.PassthroughAuth

  doctest ExFTP.Auth.PassthroughAuth
  doctest ExFTP.Authenticator

  test "valid_user?/1" do
    assert PassthroughAuth.valid_user?(Faker.Internet.slug())
    refute PassthroughAuth.valid_user?("rOoT")
  end

  test "login/2" do
    assert {:ok, _} =
             PassthroughAuth.login(Faker.Internet.slug(), %{username: Faker.Internet.slug()})

    assert {:error, _} = PassthroughAuth.login(Faker.Internet.slug(), %{})
    assert {:error, _} = PassthroughAuth.login(Faker.Internet.slug(), %{username: "RooT"})
  end

  test "authenticated?/1" do
    assert PassthroughAuth.authenticated?(%{authenticated: true})
    refute PassthroughAuth.authenticated?(%{})
  end
end
