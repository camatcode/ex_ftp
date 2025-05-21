# SPDX-License-Identifier: Apache-2.0
defmodule ExFTP.Storage.Common do
  @moduledoc """
  A module covering the low-level FTP responses

  <!-- tabs-open -->

  #{ExFTP.Doc.related(["`ExFTP.Worker`"])}

  #{ExFTP.Doc.resources()}

  <!-- tabs-close -->
  """

  import ExFTP.Common

  alias ExFTP.PassiveSocket

  @directory_action_ok 257
  @directory_action_not_taken 521
  @file_action_ok 250
  @file_action_not_taken 550
  @file_status_ok 213
  @opening_data_connection 150
  @closing_connection_success 226
  @action_aborted 451

  @doc """
  Responds to FTP's `PWD` command

  > #### RFC 959: PRINT WORKING DIRECTORY (PWD) {: .tip}
  > This command causes the name of the current working
  > directory to be returned in the reply.

  <!-- tabs-open -->

  ### 🏷️ Server State
    * **storage_connector** :: `ExFTP.StorageConnector`
    * **socket** :: `t:ExFTP.StorageConnector.socket/0`
    * **connector_state** :: `t:ExFTP.StorageConnector.connector_state/0`

  #{ExFTP.Doc.related(["`c:ExFTP.StorageConnector.get_working_directory/1`"])}

  #{ExFTP.Doc.resources("page-32")}

  <!-- tabs-close -->
  """
  def pwd(%{storage_connector: connector, socket: socket, connector_state: connector_state} = _server_state) do
    :ok =
      send_resp(
        @directory_action_ok,
        "\"#{connector.get_working_directory(connector_state)}\" is the current directory",
        socket
      )

    connector_state
  end

  @doc """
  Responds to FTP's `CWD` command

  > #### RFC 959: CHANGE WORKING DIRECTORY (CWD) {: .tip}
  > This command allows the user to work with a different
  > directory or dataset for file storage or retrieval without
  > altering their login or accounting information.  Transfer
  > parameters are similarly unchanged.  The argument is a
  > pathname specifying a directory or other system dependent
  > file group designator.

  <!-- tabs-open -->

  ### 🏷️ Server State
    * **storage_connector** :: `ExFTP.StorageConnector`
    * **path** :: `t:ExFTP.StorageConnector.path/0`
    * **socket** :: `t:ExFTP.StorageConnector.socket/0`
    * **connector_state** :: `t:ExFTP.StorageConnector.connector_state/0`

  #{ExFTP.Doc.related(["`c:ExFTP.StorageConnector.get_working_directory/1`"])}

  #{ExFTP.Doc.resources("page-26")}

  <!-- tabs-close -->
  """

  def cwd(%{storage_connector: connector, path: path, socket: socket, connector_state: connector_state} = _server_state) do
    old_wd = connector.get_working_directory(connector_state)
    new_wd = change_prefix(old_wd, path)

    if connector.directory_exists?(new_wd, connector_state) do
      send_resp(@file_action_ok, "Directory changed successfully.", socket)
      Map.put(connector_state, :current_working_directory, new_wd)
    else
      :ok =
        send_resp(@file_action_not_taken, "Failed to change directory. Does not exist.", socket)

      connector_state
    end
  end

  @doc """
  Responds to FTP's `MKD` command

  > #### RFC 959: MAKE DIRECTORY (MKD) {: .tip}
  > This command causes the directory specified in the pathname
  > to be created as a directory (if the pathname is absolute)
  > or as a subdirectory of the current working directory (if
  > the pathname is relative).

  <!-- tabs-open -->

  ### 🏷️ Server State
    * **storage_connector** :: `ExFTP.StorageConnector`
    * **path** :: `t:ExFTP.StorageConnector.path/0`
    * **socket** :: `t:ExFTP.StorageConnector.socket/0`
    * **connector_state** :: `t:ExFTP.StorageConnector.connector_state/0`

  #{ExFTP.Doc.related(["`c:ExFTP.StorageConnector.make_directory/2`"])}

  #{ExFTP.Doc.resources("page-32")}

  <!-- tabs-close -->
  """
  def mkd(%{storage_connector: connector, path: path, socket: socket, connector_state: connector_state} = _server_state) do
    wd = connector.get_working_directory(connector_state)
    new_d = change_prefix(wd, path)

    if connector.directory_exists?(new_d, connector_state) do
      :ok =
        send_resp(@directory_action_not_taken, "\"#{new_d}\" directory already exists", socket)
    else
      new_d
      |> connector.make_directory(connector_state)
      |> case do
        {:ok, connector_state} ->
          send_resp(@directory_action_ok, "\"#{new_d}\" directory created.", socket)
          connector_state

        _ ->
          send_resp(@directory_action_not_taken, "Failed to make directory.", socket)
          connector_state
      end
    end
  end

  @doc """
  Responds to FTP's `RMD` command

  > #### RFC 959: REMOVE DIRECTORY (RMD) {: .tip}
  > This command causes the directory specified in the pathname
  > to be removed as a directory (if the pathname is absolute)
  > or as a subdirectory of the current working directory (if
  > the pathname is relative).

  <!-- tabs-open -->

  ### 🏷️ Server State
    * **storage_connector** :: `ExFTP.StorageConnector`
    * **path** :: `t:ExFTP.StorageConnector.path/0`
    * **socket** :: `t:ExFTP.StorageConnector.socket/0`
    * **connector_state** :: `t:ExFTP.StorageConnector.connector_state/0`

  #{ExFTP.Doc.related(["`c:ExFTP.StorageConnector.delete_directory/2`"])}

  #{ExFTP.Doc.resources("page-32")}

  <!-- tabs-close -->
  """
  def rmd(%{storage_connector: connector, path: path, socket: socket, connector_state: connector_state} = _server_state) do
    wd = connector.get_working_directory(connector_state)
    rm_d = change_prefix(wd, path)

    rm_d
    |> connector.delete_directory(connector_state)
    |> case do
      {:ok, connector_state} ->
        send_resp(@file_action_ok, "\"#{rm_d}\" directory removed.", socket)
        # kickout if you just RM'd the dir you're in
        new_working_dir = if wd == rm_d, do: change_prefix(wd, ".."), else: wd

        Map.put(connector_state, :current_working_directory, new_working_dir)

      _ ->
        send_resp(@file_action_not_taken, "Failed to remove directory.", socket)
        connector_state
    end
  end

  @typedoc """
  A `t:port/0` representing a temporary, negotiated passive socket to communicate with an FTP client.

  <!-- tabs-open -->

  ### ⚠️ Reminders
  > #### Sockets are everywhere {: .tip}
  >
  > This socket represents a temporary TCP connection between the FTP Server and the client
  >
  > While related, this passive socket is not the normal socket, which is often on port 21.

  #{ExFTP.Doc.resources("page-28")}
  <!-- tabs-close -->
  """
  @type pasv_socket :: port()

  @doc """
  Responds to FTP's `LIST` command

  > #### RFC 959: LIST (LIST) {: .tip}
  > This command causes a list to be sent from the server to the
  > passive DTP.  If the pathname specifies a directory or other
  > group of files, the server should transfer a list of files
  > in the specified directory.  If the pathname specifies a
  > file then the server should send current information on the
  > file.  A null argument implies the user's current working or
  > default directory.  The data transfer is over the data
  > connection in type ASCII or type EBCDIC.  (The user must
  > ensure that the TYPE is appropriately ASCII or EBCDIC).
  > Since the information on a file may vary widely from system
  > to system, this information may be hard to use automatically
  > in a program, but may be quite useful to a human user.

  <!-- tabs-open -->

  ### 🏷️ Server State
    * **storage_connector** :: `ExFTP.StorageConnector`
    * **path** :: `t:ExFTP.StorageConnector.path/0`
    * **socket** :: `t:ExFTP.StorageConnector.socket/0`
    * **pasv** :: `t:pasv_socket/0`
    * **connector_state** :: `t:ExFTP.StorageConnector.connector_state/0`
    * **include_hidden** :: `t:boolean/0` - Whether to include hidden files/dirs

  #{ExFTP.Doc.related(["`c:ExFTP.StorageConnector.get_directory_contents/2`"])}

  #{ExFTP.Doc.resources("page-32")}

  <!-- tabs-close -->
  """
  def list(
        %{
          socket: socket,
          storage_connector: connector,
          connector_state: connector_state,
          pasv: pasv,
          path: path,
          include_hidden: include_hidden
        } = _server_state
      ) do
    send_resp(@opening_data_connection, "Here comes the directory listing.", socket)

    wd = change_prefix(connector.get_working_directory(connector_state), path)
    hidden_dirs = if include_hidden, do: get_hidden_roots(connector, connector_state), else: []

    items =
      wd
      |> connector.get_directory_contents(connector_state)
      |> case do
        {:ok, contents} ->
          if_result =
            if include_hidden do
              hidden_dirs ++ contents
            else
              Enum.reject(contents, &hidden?/1)
            end

          Enum.sort_by(if_result, & &1.file_name)

        _ ->
          if include_hidden, do: hidden_dirs, else: []
      end
      |> Enum.map(&format_content(&1))

    if Enum.empty?(items) do
      PassiveSocket.write(pasv, "", close_after_write: true)
    else
      :ok = Enum.each(items, &PassiveSocket.write(pasv, &1, close_after_write: false))

      PassiveSocket.close(pasv)
    end

    send_resp(@closing_connection_success, "Directory send OK.", socket)
    connector_state
  end

  @doc """
  Responds to FTP's `NLST` command

  > #### RFC 959: NAME LIST (NLST) {: .tip}
  > This command causes a directory listing to be sent from
  > server to user site.  The pathname should specify a
  > directory or other system-specific file group descriptor; a
  > null argument implies the current directory.  The server
  > will return a stream of names of files and no other
  > information.  The data will be transferred in ASCII or
  > EBCDIC type over the data connection as valid pathname
  > strings separated by <CRLF> or <NL>.  (Again the user must
  > ensure that the TYPE is correct.)  This command is intended
  > to return information that can be used by a program to
  > further process the files automatically.  For example, in
  > the implementation of a "multiple get" function.

  <!-- tabs-open -->

  ### 🏷️ Server State
    * **storage_connector** :: `ExFTP.StorageConnector`
    * **path** :: `t:ExFTP.StorageConnector.path/0`
    * **socket** :: `t:ExFTP.StorageConnector.socket/0`
    * **pasv** :: `t:pasv_socket/0`
    * **connector_state** :: `t:ExFTP.StorageConnector.connector_state/0`
    * **include_hidden** :: `t:boolean/0` - Whether to include hidden files/dirs

  #{ExFTP.Doc.related(["`c:ExFTP.StorageConnector.get_directory_contents/2`"])}

  #{ExFTP.Doc.resources("page-33")}

  <!-- tabs-close -->
  """
  def nlst(
        %{
          socket: socket,
          storage_connector: connector,
          connector_state: connector_state,
          pasv: pasv,
          path: path,
          include_hidden: include_hidden
        } = _server_state
      ) do
    send_resp(@opening_data_connection, "Here comes the directory listing.", socket)

    wd = change_prefix(connector.get_working_directory(connector_state), path)

    hidden_dirs = if include_hidden, do: get_hidden_roots(connector, connector_state), else: []

    items =
      wd
      |> connector.get_directory_contents(connector_state)
      |> case do
        {:ok, contents} ->
          if_result =
            if include_hidden do
              hidden_dirs ++ contents
            else
              Enum.reject(contents, &hidden?/1)
            end

          Enum.sort_by(if_result, & &1.file_name)

        _ ->
          if include_hidden, do: hidden_dirs, else: []
      end
      |> Enum.map(&format_name(&1))

    if Enum.empty?(items) do
      PassiveSocket.write(pasv, "", close_after_write: true)
    else
      :ok = Enum.each(items, &PassiveSocket.write(pasv, &1, close_after_write: false))

      PassiveSocket.close(pasv)
    end

    send_resp(@closing_connection_success, "Directory send OK.", socket)
    connector_state
  end

  @doc """
  Responds to FTP's `RETR` command

  > #### RFC 959: RETRIEVE (RETR) {: .tip}
  > This command causes the server-DTP to transfer a copy of the
  > file, specified in the pathname, to the server- or user-DTP
  > at the other end of the data connection.  The status and
  > contents of the file at the server site shall be unaffected.

  <!-- tabs-open -->

  ### 🏷️ Server State
    * **storage_connector** :: `ExFTP.StorageConnector`
    * **path** :: `t:ExFTP.StorageConnector.path/0`
    * **socket** :: `t:ExFTP.StorageConnector.socket/0`
    * **pasv** :: `t:pasv_socket/0`
    * **connector_state** :: `t:ExFTP.StorageConnector.connector_state/0`

  #{ExFTP.Doc.related(["`c:ExFTP.StorageConnector.get_content/2`"])}

  #{ExFTP.Doc.resources("page-30")}

  <!-- tabs-close -->
  """
  def retr(
        %{storage_connector: connector, path: path, socket: socket, pasv: pasv, connector_state: connector_state} =
          _server_state
      ) do
    w_path = change_prefix(connector.get_working_directory(connector_state), path)

    :ok =
      send_resp(
        @opening_data_connection,
        "Opening BINARY mode data connection for #{w_path}",
        socket
      )

    w_path
    |> connector.get_content(connector_state)
    |> case do
      {:ok, stream} ->
        PassiveSocket.write(pasv, stream, close_after_write: true)
        send_resp(@closing_connection_success, "Transfer complete.", socket)

      _ ->
        send_resp(@action_aborted, "File not found.", socket)
        PassiveSocket.close(pasv)
    end

    connector_state
  end

  @doc """
  Responds to FTP's `SIZE` command

  > #### RFC 3659: SIZE OF FILE (SIZE) {: .tip}
  > The FTP command, SIZE OF FILE (SIZE), is used to obtain the transfer
  > size of a file from the server-FTP process.  This is the exact number
  > of octets (8 bit bytes) that would be transmitted over the data
  > connection should that file be transmitted.  This value will change
  > depending on the current STRUcture, MODE, and TYPE of the data
  > connection or of a data connection that would be created were one
  > created now.  Thus, the result of the SIZE command is dependent on
  > the currently established STRU, MODE, and TYPE parameters.
  >
  > The SIZE command returns how many octets would be transferred if the
  > file were to be transferred using the current transfer structure,
  > mode, and type.  This command is normally used in conjunction with
  > the RESTART (REST) command when STORing a file to a remote server in
  > STREAM mode, to determine the restart point.  The server-PI might
  > need to read the partially transferred file, do any appropriate
  > conversion, and count the number of octets that would be generated
  > when sending the file in order to correctly respond to this command.
  > Estimates of the file transfer size MUST NOT be returned; only
  > precise information is acceptable.

  <!-- tabs-open -->

  ### 🏷️ Server State
    * **storage_connector** :: `ExFTP.StorageConnector`
    * **path** :: `t:ExFTP.StorageConnector.path/0`
    * **socket** :: `t:ExFTP.StorageConnector.socket/0`
    * **connector_state** :: `t:ExFTP.StorageConnector.connector_state/0`

  #{ExFTP.Doc.related(["`c:ExFTP.StorageConnector.get_content_info/2`"])}

  #{ExFTP.Doc.resources(nil, "section-4")}

  <!-- tabs-close -->
  """
  def size(%{storage_connector: connector, path: path, socket: socket, connector_state: connector_state} = _server_state) do
    w_path = change_prefix(connector.get_working_directory(connector_state), path)

    w_path
    |> connector.get_content_info(connector_state)
    |> case do
      {:ok, %{size: size}} ->
        send_resp(@file_status_ok, "#{size}", socket)

      _ ->
        send_resp(@file_action_not_taken, "Could not get file size.", socket)
    end

    connector_state
  end

  @doc """
  Responds to FTP's `STOR` command

  > #### RFC 959: STORE (STOR) {: .tip}
  > This command causes the server-DTP to accept the data
  > transferred via the data connection and to store the data as
  > a file at the server site.  If the file specified in the
  > pathname exists at the server site, then its contents shall
  > be replaced by the data being transferred.  A new file is
  > created at the server site if the file specified in the
  > pathname does not already exist.

  <!-- tabs-open -->

  ### 🏷️ Server State
    * **storage_connector** :: `ExFTP.StorageConnector`
    * **path** :: `t:ExFTP.StorageConnector.path/0`
    * **socket** :: `t:ExFTP.StorageConnector.socket/0`
    * **pasv** :: `t:pasv_socket/0`
    * **connector_state** :: `t:ExFTP.StorageConnector.connector_state/0`

  #{ExFTP.Doc.related(["`c:ExFTP.StorageConnector.get_content/2`"])}

  #{ExFTP.Doc.resources("page-30")}

  <!-- tabs-close -->
  """
  def stor(
        %{storage_connector: connector, path: path, socket: socket, pasv: pasv, connector_state: connector_state} =
          _server_state
      ) do
    w_path = change_prefix(connector.get_working_directory(connector_state), path)

    send_resp(@opening_data_connection, "Ok to send data.", socket)

    PassiveSocket.read(
      pasv,
      connector.create_write_func(
        w_path,
        connector_state,
        chunk_size: 5 * 1024 * 1024
      )
    )

    ExFTP.Common.send_resp(@closing_connection_success, "Transfer Complete.", socket)

    connector_state
  end

  @doc """
  Responds to FTP's `DELE` command

  > #### RFC 959: DELETE (DELE) {: .tip}
  > This command causes the file specified in the pathname to be
  > deleted at the server site.  If an extra level of protection
  > is desired (such as the query, "Do you really wish to
  > delete?"), it should be provided by the user-FTP process.

  <!-- tabs-open -->

  ### 🏷️ Server State
    * **storage_connector** :: `ExFTP.StorageConnector`
    * **path** :: `t:ExFTP.StorageConnector.path/0`
    * **socket** :: `t:ExFTP.StorageConnector.socket/0`
    * **connector_state** :: `t:ExFTP.StorageConnector.connector_state/0`

  #{ExFTP.Doc.related(["`c:ExFTP.StorageConnector.delete_file/2`"])}

  #{ExFTP.Doc.resources("page-32")}

  <!-- tabs-close -->
  """
  def dele(%{storage_connector: connector, path: path, socket: socket, connector_state: connector_state} = _server_state) do
    w_path = change_prefix(connector.get_working_directory(connector_state), path)

    w_path
    |> connector.delete_file(connector_state)
    |> case do
      {:ok, connector_state} ->
        send_resp(@file_action_ok, "\"#{w_path}\" directory removed.", socket)
        connector_state

      _ ->
        send_resp(@file_action_not_taken, "Failed to remove file.", socket)
        connector_state
    end
  end

  @doc """
  Takes a map and ensures the keys are atoms and use the correct conventions
  """
  def prepare(m) do
    prepare_keys(m)
  end

  @doc """
  Ensures you get a valid config according to a module, **mod**
  """
  def validate_config(mod) do
    with {:ok, config} <- get_storage_config() do
      validated = mod.build(config)
      {:ok, validated}
    end
  end

  @doc """
  Chunks a stream into `chunk_size` pieces for upload

  <!-- tabs-open -->

  ### 🏷️ Params
    * **stream** :: A Stream to read from
    * **opts** :: `t:ExFTP.StorageConnector.path/0`
      * **chunk_size** :: `t:pos_integer()`

  <!-- tabs-close -->
  """
  def chunk_stream(stream, opts) do
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

  defp get_storage_config do
    :ex_ftp
    |> Application.get_env(:storage_config)
    |> case do
      nil -> {:error, "No :storage_config found"}
      config -> {:ok, config}
    end
  end

  defp hidden?(%{file_name: file_name}), do: String.starts_with?(file_name, ".")

  defp format_name(%{file_name: file_name, type: type}) do
    if type == :directory, do: file_name, else: file_name <> "/"
  end

  defp format_content(%{file_name: file_name, modified_datetime: date, size: size, access: access, type: type}) do
    formatted_date = Calendar.strftime(date, "%b %d  %Y")

    type =
      case type do
        :directory -> "d"
        :symlink -> "l"
        _ -> "-"
      end

    access =
      case access do
        :read -> "r--"
        :write -> "-w-"
        :read_write -> "rw-"
        _ -> "---"
      end

    size = size |> to_string() |> String.pad_leading(16)

    owner = " 0"
    group = "        0"
    unknown_val = String.pad_leading("1", 5)
    permissions = "#{type}#{access}r--r--"

    "#{permissions}#{unknown_val}#{owner}#{group}#{size} #{formatted_date} #{file_name}"
  end

  defp change_prefix(nil, path), do: change_prefix("/", path)

  defp change_prefix(current_prefix, path) do
    cond do
      String.starts_with?(path, "/") ->
        Path.expand(path)

      String.starts_with?(path, "~") ->
        path |> String.replace("~", "/") |> Path.expand()

      true ->
        current_prefix
        |> Path.join(path)
        |> Path.expand()
    end
  end

  defp get_hidden_roots(connector, connector_state) do
    w_path = change_prefix(connector.get_working_directory(connector_state), ".")

    {:ok, first} = connector.get_content_info(w_path, connector_state)
    first = Map.put(first, :file_name, ".")
    w_path = change_prefix(connector.get_working_directory(connector_state), "..")
    {:ok, second} = connector.get_content_info(w_path, connector_state)
    second = Map.put(second, :file_name, "..")
    [first, second]
  end

  defp prepare_keys(m) do
    m
    |> snake_case_keys()
    |> atomize_keys()
  end

  defp snake_case_keys(m) do
    Enum.map(m, fn {key, val} ->
      {ProperCase.snake_case(key), val}
    end)
  end

  defp atomize_keys(m) do
    Enum.map(m, fn {key, val} ->
      key = String.to_atom(key)
      {key, val}
    end)
  end
end
