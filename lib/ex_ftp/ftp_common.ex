defmodule ExFTP.Common do
  @moduledoc false

  require Logger

  import Bitwise

  alias ExFTP.PassiveSocket

  def send_resp(code, msg, socket) do
    response = "#{code} #{msg}\r\n"
    Logger.info("Sending FTP response:\t#{inspect(response)}")
    :gen_tcp.send(socket, response)
  end

  def with_pasv_socket(%{pasv_socket: pasv} = state) do
    if pasv && Process.alive?(pasv) do
      {:ok, pasv}
    else
      :ok = send_resp(550, "LIST failed. PASV mode required.", Map.get(state, :socket))
      {:noreply, state}
    end
  end

  def ip_port_to_pasv(ip, port) do
    upper_port = port >>> 8
    lower_port = port &&& 255
    {a, b, c, d} = ip
    # Convert IP and port (e.g. 64943) to (192,168,1,22,253,175)
    "#{a},#{b},#{c},#{d},#{upper_port},#{lower_port}"
  end

  def quit(%{socket: socket} = state) do
    Logger.info("Shutting down. Client closed connection.")

    :ok = send_resp(221, "Closing connection.", socket)

    :gen_tcp.close(socket)

    pasv = state[:pasv_socket]

    if pasv && Process.alive?(pasv) do
      PassiveSocket.close(pasv)
    end

    {:stop, :normal, state}
  end

  def chunk_stream(stream, opts \\ []) do
    opts = Keyword.merge([chunk_size: 5 * 1024 * 1024], opts)

    Stream.chunk_while(
      stream,
      <<>>,
      fn data, chunk ->
        chunk = chunk <> data

        if byte_size(chunk) >= opts[:chunk_size] do
          {:cont, chunk, <<>>}
        else
          {:cont, chunk}
        end
      end,
      fn
        <<>> -> {:cont, []}
        chunk -> {:cont, chunk, []}
      end
    )
  end
end
