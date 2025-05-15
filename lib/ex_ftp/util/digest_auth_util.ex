# SPDX-License-Identifier: Apache-2.0
defmodule ExFTP.DigestAuthUtil do
  @moduledoc false

  @nc "00000001"
  def request(url, http_method, username, password) do
    %{path: path} = URI.parse(url)

    with {:ok, digest_info} <- init_digest(url, http_method) do
      response = create_response(http_method, username, password, digest_info, path)

      auth_header_value =
        create_auth_header_value(path, username, response, digest_info)

      make_auth_call(url, http_method, auth_header_value)
    end
  end

  def create_auth_header_value(path, username, response, %{
        realm: realm,
        nonce: nonce,
        use_auth_int: use_auth_int?,
        cnonce: cnonce,
        opaque: opaque,
        algorithm: algorithm
      }) do
    qop = if use_auth_int?, do: "auth-int", else: "auth"

    "Digest algorithm=\"#{algorithm}\",username=\"#{username}\",realm=\"#{realm}\",nonce=\"#{nonce}\",uri=\"#{path}\",qop=#{qop},nc=#{@nc},cnonce=\"#{cnonce}\", response=\"#{response}\", opaque=\"#{opaque}\""
  end

  defp init_digest(url, http_method) do
    Req.request(
      url: url,
      method: http_method,
      raw: true,
      redirect: true
    )
    |> case do
      {:ok, %{headers: %{"www-authenticate" => [digest_info]}, body: entity_body}} ->
        with {:ok, parsed} <- parse_digest(digest_info) do
          {:ok, Map.put(parsed, :entity_body, entity_body)}
        end

      _ ->
        {:error, "valid headers not found"}
    end
  end

  defp make_auth_call(url, http_method, auth_header_value) do
    Req.request(
      url: url,
      method: http_method,
      headers: [{"Authorization", auth_header_value}],
      redirect: true
    )
  end

  def create_response(
        http_method,
        username,
        password,
        digest_info,
        path
      ) do
    hash_1 = make_hash_1(username, password, digest_info)
    hash_2 = make_hash_2(http_method, path, digest_info)

    make_response(hash_1, hash_2, digest_info)
  end

  defp make_hash_1(username, password, %{realm: realm, is_sess: false, crypto_algo: algo}) do
    hash(algo, [username, realm, password])
  end

  defp make_hash_1(username, password, %{
         realm: realm,
         is_sess: true,
         crypto_algo: algo,
         nonce: nonce,
         cnonce: cnonce
       }) do
    inner_hash = hash(algo, [username, realm, password])
    hash(algo, [inner_hash, nonce, cnonce])
  end

  defp make_hash_2(
         http_method,
         path,
         %{
           crypto_algo: algo,
           entity_body: entity_body,
           use_auth_int: use_auth_int?
         }
       ) do
    http_method_str = Atom.to_string(http_method) |> String.upcase()

    hash_elements =
      if use_auth_int?,
        do: [http_method_str, path, hash(algo, [entity_body])],
        else: [http_method_str, path]

    hash(algo, hash_elements)
  end

  defp make_response(
         hash_1,
         hash_2,
         %{use_auth_int: true, crypto_algo: algo, nonce: nonce, cnonce: cnonce}
       ) do
    hash(algo, [hash_1, nonce, @nc, cnonce, "auth-int", hash_2])
  end

  defp make_response(
         hash_1,
         hash_2,
         %{use_auth_int: false, crypto_algo: algo, nonce: nonce, qop: []}
       ) do
    hash(algo, [hash_1, nonce, hash_2])
  end

  defp make_response(
         hash_1,
         hash_2,
         %{use_auth_int: false, crypto_algo: algo, nonce: nonce, cnonce: cnonce}
       ) do
    hash(algo, [hash_1, nonce, @nc, cnonce, "auth", hash_2])
  end

  def parse_digest(digest_info) do
    parsed =
      digest_info
      |> String.split(~r/,(?=(?:[^\"]*\"[^\"]*\")*[^\"]*$)/)
      |> Enum.map(fn part ->
        [k, v] =
          part
          |> String.trim()
          |> String.replace("Digest", "")
          |> String.replace("\"", "")
          |> String.split("=", parts: 2)
          |> Enum.map(&String.trim/1)

        {String.to_atom(k), v}
      end)
      |> Enum.map(&serialize/1)
      |> Map.new()
      |> Map.put_new(:algorithm, "MD5")
      |> Map.put_new(:qop, [])

    algo_str = Map.get(parsed, :algorithm)
    algo = algo_from_string(algo_str)
    cnonce = hash(algo, [random_string(16)])

    use_auth_int? =
      Map.get(parsed, :qop)
      |> Enum.member?("auth-int")

    {:ok,
     parsed
     |> Map.put(:cnonce, cnonce)
     |> Map.put(:crypto_algo, algo)
     |> Map.put(:is_sess, sess?(algo_str))
     |> Map.put(:use_auth_int, use_auth_int?)}
  end

  def sess?(algo_str), do: algo_str |> String.downcase() |> String.contains?("sess")

  defp algo_from_string(algo_str) do
    algo_str
    |> String.replace("-sess", "")
    |> String.replace("-", "")
    |> String.trim()
    |> String.downcase()
    |> String.to_atom()
  end

  defp hash(algo, hash_elements, joiner \\ ":") do
    algo
    |> :crypto.hash(Enum.join(hash_elements, joiner))
    |> Base.encode16(case: :lower)
  end

  defp serialize({:qop, v}) do
    v =
      v
      |> String.split(",")
      |> Enum.map(&String.trim/1)

    {:qop, v}
  end

  defp serialize({k, v}), do: {k, v}

  @spec random_string(Integer.t()) :: String.t()
  defp random_string(length) do
    length
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64()
    |> binary_part(0, length)
  end
end
