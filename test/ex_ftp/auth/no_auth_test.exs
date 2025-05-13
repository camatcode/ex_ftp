defmodule ExFTP.Auth.NoAuthTest do
  @moduledoc false

  use ExUnit.Case

  alias ExFTP.Auth.NoAuth

  doctest ExFTP.Auth.NoAuth

  test "valid_user?/1" do
    assert NoAuth.valid_user?(Faker.Internet.slug())
    assert NoAuth.valid_user?("rOoT")
  end

  test "login/2" do
    assert {:ok, _} =
             NoAuth.login(Faker.Internet.slug(), %{username: Faker.Internet.slug()})

    assert {:ok, _} = NoAuth.login(Faker.Internet.slug(), %{})
    assert {:ok, _} = NoAuth.login(Faker.Internet.slug(), %{username: "RooT"})
  end

  test "authenticated?/1" do
    assert NoAuth.authenticated?(%{authenticated: true})
    assert NoAuth.authenticated?(%{})
  end
end
