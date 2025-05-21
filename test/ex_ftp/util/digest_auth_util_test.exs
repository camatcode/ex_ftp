defmodule ExFTP.DigestAuthUtilTest do
  @moduledoc false

  use ExUnit.Case

  alias ExFTP.DigestAuthUtil

  doctest ExFTP.DigestAuthUtil

  describe "auth, md5" do
    test "RFC example - auth, md5" do
      username = "Mufasa"
      password = "Circle Of Life"
      path = "/dir/index.html"
      realm = "testrealm@host.com"
      qop = "auth,auth-int"
      nonce = "dcd98b7102dd2f0e8b11d0f600bfb0c093"
      opaque = "5ccc069c403ebaf9f0171e9517f40e41"

      example_digest =
        "Digest realm=\"#{realm}\",qop=\"#{qop}\",nonce=\"#{nonce}\",opaque=\"#{opaque}\""

      {:ok, digest_info} = DigestAuthUtil.parse_digest(example_digest)

      cnonce = "0a4f113b"

      digest_info =
        digest_info
        |> Map.put(:use_auth_int, false)
        |> Map.put(:entity_body, "")
        |> Map.put(:cnonce, cnonce)

      assert "6629fae49393a05397450978507c4ef1" =
               resp = DigestAuthUtil.create_response(:get, username, password, digest_info, path)

      algorithm = "MD5"
      uri = "/dir/index.html"
      qop = "auth"
      nc = "00000001"

      expected =
        "Digest algorithm=\"#{algorithm}\",username=\"#{username}\",realm=\"#{realm}\",nonce=\"#{nonce}\",uri=\"#{uri}\",qop=#{qop},nc=#{nc},cnonce=\"#{cnonce}\", response=\"#{resp}\", opaque=\"#{opaque}\""

      assert expected ==
               DigestAuthUtil.create_auth_header_value(path, username, resp, digest_info)
    end

    test "with httpbin - auth , md5" do
      user = Faker.Internet.user_name()
      password = Faker.Internet.slug()
      url = "https://httpbin.dev/digest-auth/auth/#{user}/#{password}/MD5"
      method = :get
      assert {:ok, %{status: 200}} = DigestAuthUtil.request(url, method, user, password)
    end
  end

  describe "auth, sha256" do
    test "with httpbin - auth , sha256" do
      user = Faker.Internet.user_name()
      password = Faker.Internet.slug()
      url = "https://httpbin.dev/digest-auth/auth/#{user}/#{password}/SHA-256"
      method = :get
      assert {:ok, %{status: 200}} = DigestAuthUtil.request(url, method, user, password)
    end
  end
end
