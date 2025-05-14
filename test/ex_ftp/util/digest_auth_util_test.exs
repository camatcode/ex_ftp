defmodule ExFTP.DigestAuthUtilTest do
  @moduledoc false

  use ExUnit.Case

  alias ExFTP.DigestAuthUtil

  doctest ExFTP.DigestAuthUtil

  test "wikipedia example" do
    username = "Mufasa"
    password = "Circle Of Life"
    path = "/dir/index.html"

    example_digest =
      "Digest realm=\"testrealm@host.com\",qop=\"auth,auth-int\",nonce=\"dcd98b7102dd2f0e8b11d0f600bfb0c093\",opaque=\"5ccc069c403ebaf9f0171e9517f40e41\""

    {:ok, digest_info} = DigestAuthUtil.parse_digest(example_digest)

    digest_info =
      digest_info
      |> Map.put(:use_auth_int, false)
      |> Map.put(:entity_body, "")
      |> Map.put(:cnonce, "0a4f113b")

    resp = DigestAuthUtil.create_response(:get, username, password, digest_info, path)
    _auth_header_value = DigestAuthUtil.create_auth_header_value(path, username, resp, digest_info)
  end

  test "workflow - auth , md5" do
    user = Faker.Internet.user_name()
    password = Faker.Internet.slug()
    url = "https://httpbin.dev/digest-auth/auth/#{user}/#{password}/MD5"
    method = :get
    assert {:ok, %{status: 200}} = DigestAuthUtil.request(url, method, user, password)
  end

  test "workflow - auth-int , md5" do
    user = Faker.Internet.user_name()
    password = Faker.Internet.slug()
    url = "https://httpbin.org/digest-auth/auth-int/#{user}/#{password}/MD5"
    method = :get
    assert {:ok, %{status: 200}} = DigestAuthUtil.request(url, method, user, password)
  end


  test "workflow - auth , sha256" do
    user = Faker.Internet.user_name()
    password = Faker.Internet.slug()
    url = "https://httpbin.dev/digest-auth/auth/#{user}/#{password}/SHA-256"
    method = :get
    assert {:ok, %{status: 200}} = DigestAuthUtil.request(url, method, user, password)
  end
end
