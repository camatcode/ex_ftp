<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/camatcode/ex_ftp/refs/heads/main/assets/ex_ftp-logo-dark.png">
    <source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/camatcode/ex_ftp/refs/heads/main/assets/ex_ftp-logo-light.png">
    <img alt="ex_ftp logo" src="https://raw.githubusercontent.com/camatcode/ex_ftp/refs/heads/main/assets/ex_ftp-logo-light.png" width="320">
  </picture>
</p>

<p align="center" id="top">
  An extendable, lightweight FTP server with cloud integrations already built in
</p>

<p align="center">
  <a href="https://hex.pm/packages/ex_ftp">
    <img alt="Hex Version" src="https://img.shields.io/hexpm/v/ex_ftp.svg">
  </a>
  <a href="https://hexdocs.pm/ex_ftp">
    <img alt="Hex Docs" src="http://img.shields.io/badge/hex.pm-docs-green.svg?style=flat">
  </a>
  <a href="https://opensource.org/licenses/Apache-2.0">
    <img alt="Apache 2 License" src="https://img.shields.io/hexpm/l/oban">
  </a>
  <a href="https://github.com/camatcode/ex_ftp/actions?query=branch%3Amain++">
    <img alt="ci status" src="https://github.com/camatcode/ex_ftp/workflows/ci/badge.svg">
  </a>
  <a href='https://coveralls.io/github/camatcode/ex_ftp?branch=main'>
    <img src='https://coveralls.io/repos/github/camatcode/ex_ftp/badge.svg?branch=main' alt='Coverage Status' />
  </a>
  <a href="https://mastodon.social/@scrum_log" target="_blank" rel="noopener noreferrer">
    <img alt="Mastodon Follow" src="https://img.shields.io/badge/mastodon-%40scrum__log%40mastodon.social-purple?color=6364ff">
  </a>
</p>

## Table of Contents

- [Installation](#installation)
- [Reckless Quick Start](#reckless-quick-start)
- [Configuration](#configuration)
  - [Server Config](#1-server-config)
  - [Choosing an Authenticator](#2-choose-an-authenticator)
  - [Choosing a Storage Connector](#3-choose-a-storage-connector)
- [Authenticators](#authenticators)
  - [No Auth](#authenticator-no-auth)
  - [Passthrough Auth](#authenticator-passthrough-auth)
  - [HTTP Basic Auth](#authenticator-http-basic-auth)
  - [HTTP Digest Access Auth](#authenticator-http-digest-access-auth)
  - [Bearer Token Auth](#authenticator-bearer-token-auth)
  - [Webhook Auth](#authenticator-webhook-auth)
  - [Custom Auth](#authenticator-custom-auth)
- [Storage Connectors](#storage-connectors)
  - [File](#storage-connector-file)
  - [S3](#storage-connector-s3)
    - [Using Minio or LocalStack](#using-minio-or-localstack)
  - [Others through S3Proxy](#storage-connector-others-through-s3proxy)
  - [Custom Storage Connector](#custom-storage-connector)
    - [User-Aware Storage Connectors](#user-aware-storage-connectors)
- [Technical Details](#technical-details)
  - [Supported Commands](#supported-commands)
  - [Notes about Fly.io](#notes-about-flyio)
- [Special Thanks](#special-thanks)

## Installation

Add `:ex_ftp` to your list of deps in `mix.exs`:

```elixir
{:ex_ftp, "~> 1.0"}
```

Then run `mix deps.get` to install ExFTP and its dependencies.

## Reckless Quick Start

* Configure ex_ftp 
  * to use the file system, 
  * start on port 4040, 
  * don't include auth

```elixir
config :ex_ftp,
  ftp_port: "FTP_PORT" |> System.get_env("4040") |> String.to_integer(),
  min_passive_port: "MIN_PASSIVE_PORT" |> System.get_env("40002") |> String.to_integer(),
  max_passive_port: "MAX_PASSIVE_PORT" |> System.get_env("40007") |> String.to_integer(),
  authenticator: ExFTP.Auth.NoAuth,
  authenticator_config: %{},
  storage_connector: ExFTP.Storage.FileConnector
```

* Run `mix run --no-halt`

```
17:13:22.110 [info] Accepting connections on port 4040
```

* Connect using `ftp`

```bash
➜  ~ ftp localhost -p 4040      

Connected to localhost.
220 Hello from ExFTP.
Name (localhost:cam): 
331 User name okay, need password.
Password: 
502 Command not implemented.
ftp: Login failed
ftp> ls
229 Entering Extended Passive Mode (|||40002|)
150 Here comes the directory listing.
lr--r--r--    1 0        0               7 Feb 16  2024 bin -> usr/bin
dr--r--r--    1 0        0            4096 May 13  2025 boot
dr--r--r--    1 0        0            4096 Feb 16  2024 cdrom
dr--r--r--    1 0        0            4680 May 20  2025 dev
dr--r--r--    1 0        0           12288 May 19  2025 etc
dr--r--r--    1 0        0            4096 Mar 25  2025 home
lr--r--r--    1 0        0               7 Feb 16  2024 lib -> usr/lib
dr--r--r--    1 0        0            4096 Feb 06  2025 lib32
lr--r--r--    1 0        0               9 Feb 16  2024 lib64 -> usr/lib64
dr--r--r--    1 0        0            4096 Feb 06  2025 libx32
d---r--r--    1 0        0           16384 Feb 16  2024 lost+found
dr--r--r--    1 0        0            4096 Feb 29  2024 media
dr--r--r--    1 0        0            4096 Jan 09  2024 mnt
drw-r--r--    1 0        0            4096 Apr 24  2025 opt
dr--r--r--    1 0        0               0 May 02  2025 proc
d---r--r--    1 0        0            4096 Mar 25  2025 root
dr--r--r--    1 0        0            1580 May 17  2025 run
lr--r--r--    1 0        0               8 Feb 16  2024 sbin -> usr/sbin
dr--r--r--    1 0        0            4096 Jan 09  2024 srv
----r--r--    1 0        0      2147483648 Feb 16  2024 swapfile
dr--r--r--    1 0        0               0 May 02  2025 sys
dr--r--r--    1 0        0            4096 May 19  2025 timeshift
drw-r--r--    1 0        0           20480 May 20  2025 tmp
dr--r--r--    1 0        0            4096 Apr 25  2025 usr
dr--r--r--    1 0        0            4096 Mar 25  2025 var
226 Directory send OK.
ftp> ...
```

* Now, [properly configure it](#configuration).


-------

## Configuration

### 1. Server Config

Here is a detailed, example configuration.

```elixir
config :ex_ftp,
  # port to run on
  ftp_port: 21,
  # optional, reports "Hello from {server_name}" on login
  server_name: :ExFTP,
  # the address this server binds to (default: 127.0.0.1)
  ftp_addr: System.get_env("FTP_ADDR", "127.0.0.1"),
  # FTP uses temporary, negotiated ports for certain commands called passive ports
  # Choose the min and max range for these ports
  # This range would represent how many of these certain commands can run at the same time.
  # Be aware, too few options could create bottlenecks
  min_passive_port: System.get_env("MIN_PASSIVE_PORT", "40002") |> String.to_integer(),
  max_passive_port: System.get_env("MAX_PASSIVE_PORT", "40012") |> String.to_integer(),
  # See "Choose an Authenticator"
  authenticator: ExFTP.Auth.BasicAuth,
  authenticator_config: %{
    # used to login
    login_url: "https://httpbin.dev/basic-auth/",
    login_method: :get,
    # used to verify the user is still considered valid (optional)
    authenticated_url: "https://httpbin.dev/hidden-basic-auth/",
    authenticated_method: :get,
    authenticated_ttl_ms: 1000 * 60 * 60
  },
  # See "Choose a Storage Connector"
  storage_connector: ExFTP.Storage.FileConnector,
  storage_config: %{}

```


### 2. Choose an Authenticator

An `ExFTP.Authenticator` validates credentials when an FTP client sends a `USER` and `PASS` command.

Each authenticator is referenced in the `ex_ftp` config under the `authenticator` key. 

Additionally, many require a map under `authenticator_config`.

### 3. Choose a Storage Connector

An `ExFTP.StorageConnector` provides access to your chosen storage provider - with the FTP business abstracted away.

Each storage connector is referenced in the `ex_ftp` config under the `storage_connector` key.

Additionally, many require a map under `storage_config`.

-------

## Authenticators

Below are all the included authenticators.

### Authenticator: No Auth

> [!WARNING]
> This is not recommended for any production server.

When **authenticator** is `ExFTP.Auth.NoAuth`, this authenticator will completely ignore any supplied credentials and 
assume everything is authenticated.


```elixir
config :ex_ftp,
  #....
  authenticator: ExFTP.Auth.NoAuth,
  authenticator_config: %{}
 ```

-------

### Authenticator: Passthrough Auth

> [!WARNING] 
> This is not recommended for any production server.

When **authenticator** is `ExFTP.Auth.PassthroughAuth`, this authenticator will require credentials, 
but accepts any user and password combination who isn't `root`.

```elixir
config :ex_ftp,
  #....
  authenticator: ExFTP.Auth.PassthroughAuth,
  authenticator_config: %{}
 ```

[^ top](#top)

-------

### Authenticator: HTTP Basic Auth

> [!WARNING]  
> This is not recommended for situations not protected by SSL.

When **authenticator** is `ExFTP.Auth.BasicAuth`, this authenticator will call out to an HTTP endpoint that implements 
[HTTP Basic Auth](https://en.wikipedia.org/wiki/Basic_access_authentication) with the user's supplied credentials.


```elixir
config :ex_ftp,
  #....
  authenticator: ExFTP.Auth.BasicAuth,
  authenticator_config: %{
    # used to login
    login_url: "https://httpbin.dev/basic-auth/",
    login_method: :get,
    # used to verify the user is still considered valid (optional)
    authenticated_url: "https://httpbin.dev/hidden-basic-auth/",
    authenticated_method: :get,
    authenticated_ttl_ms: 1000 * 60 * 60
  }
 ```

If the endpoint responds with **HTTP 200**, the user is considered authenticated.

Additionally, if configured, ex_ftp can call out to a separate endpoint that performs basic auth to check that a user
is still considered valid.

[^ top](#top)

-------

### Authenticator: HTTP Digest Access Auth

> [!NOTE]  
> This can be used in situations where SSL is not available, though be warned, Digest Access is considered
> an obsolete protocol.

When **authenticator** is `ExFTP.Auth.DigestAuth`, this authenticator will call out to an HTTP endpoint that
implements [HTTP Digest Access Auth](https://en.wikipedia.org/wiki/Digest_access_authentication) with the user's
supplied credentials.


```elixir
config :ex_ftp,
  # ... ,
  authenticator: ExFTP.Auth.DigestAuth,
  authenticator_config: %{
    # used to login
    login_url: "https://httpbin.dev/digest-auth/auth/replace/me/MD5",
    login_method: :get,
    # used to verify the user is still considered valid (optional)
    authenticated_url: "https://httpbin.dev/digest-auth/auth/replace/me/MD5",
    authenticated_method: :get,
    authenticated_ttl_ms: 1000 * 60 * 60
  }
 ```

If, after completing the full workflow, the endpoint responds with **HTTP 200**, the user is considered authenticated.

Additionally, if configured, ex_ftp can call out to a separate endpoint that performs digest auth to check that a user
is still considered valid.

[^ top](#top)

-------

### Authenticator: Bearer Token Auth

> [!NOTE]  
> This is helpful when the "user" is actually a system or process.
>
> `username` isn't important for a Bearer token; though a provided username is still held on to.

When **authenticator** is `ExFTP.Auth.BearerAuth`, this authenticator will call out to an HTTP endpoint that implements
[Bearer Tokens](https://swagger.io/docs/specification/v3_0/authentication/bearer-authentication/) with the user's 
supplied credentials.

```elixir
config :ex_ftp,
  #....
  authenticator: ExFTP.Auth.BearerAuth,
  authenticator_config: %{
    # used to login
    login_url: "https://httpbin.dev/bearer",
    login_method: :post,
    # used to verify the user is still considered valid (optional)
    authenticated_url: "https://httpbin.dev/bearer",
    authenticated_method: :post,
    authenticated_ttl_ms: 1000 * 60 * 60
  }
 ```

If the endpoint responds with **HTTP 200**, the user is considered authenticated.

Additionally, if configured, ex_ftp can call out to a separate endpoint that performs bearer auth to check that a user
is still considered valid.


[^ top](#top)

-------

### Authenticator: Webhook Auth

> [!NOTE]  
> `password_hash` is the hash of the supplied password using the hashing algorithm dictated by the config.

When **authenticator** is `ExFTP.Auth.WebhookAuth`, this authenticator will call out to an HTTP endpoint that accepts
two query parameters: `username` and/or `password_hash`.


```elixir
config :ex_ftp,
  #....
  authenticator: ExFTP.Auth.WebhookAuth,
  authenticator_config: %{
    # used to login
    login_url: "https://httpbin.dev/status/200",
    login_method: :post,
    # affects the output of the `password_hash` query parameter
    # accepts anything that :crypto can handle
    password_hash_type: :sha256,
    # used to verify the user is still considered valid (optional)
    authenticated_url: "https://httpbin.dev/status/200",
    authenticated_method: :post,
    authenticated_ttl_ms: 1000 * 60 * 60
  }
 ```

If the endpoint responds with **HTTP 200**, the user is considered authenticated.

Additionally, if configured, ex_ftp can call out to a separate endpoint that performs webhook auth to check that a user
is still considered valid.

[^ top](#top)

-------

### Authenticator: Custom Auth

Creating your own Authenticator is simple - just implement the `ExFTP.Authenticator` behaviour.

```elixir
# SPDX-License-Identifier: Apache-2.0
defmodule MyCustomAuth do

  alias ExFTP.Authenticator
  @behaviour Authenticator

  @impl Authenticator
  @spec valid_user?(username :: Authenticator.username()) :: boolean
  def valid_user?(username) do
        # return true if the username is valid
        # return false if invalid
        # this short-circuits bad login requests,
        # if it would take longer than 5 seconds to validate a username
        #   then its best to just return true
        #   as there wouldn't be a performance benefit
  end

  @impl Authenticator
  @spec login(
          password :: Authenticator.password(),
          authenticator_state :: Authenticator.authenticator_state()
        ) :: {:ok, Authenticator.authenticator_state()} | {:error, term()}
  def login(password, authenticator_state) do
        # authenticator_state may have the key :username
        # perform initial login
        # return {:ok, current_authenticator_state} if successful
        #   authenticator_state is passed around during the session
        #   your authenticated?/1 may want this method to put 
        #     something about the password in the state
        # return {:error, anything} if unsuccessful
  end

  @impl Authenticator
  @spec authenticated?(
          authenticator_state :: Authenticator.authenticator_state()
        ) :: boolean()
  def authenticated?(authenticator_state), do
        # re-check that a user is authenticated
        # return true if successful
        # return false if unsuccessful
  end
end
```

[^ top](#top)

-------

## Storage Connectors

Below are all the included storage connectors.

### Storage Connector: File

When **storage_connector** is `ExFTP.Storage.FileConnector`, this connector will use the file system of where 
it is running.

This is the out-of-the-box behavior you'd expect from any FTP server.

```elixir
config :ex_ftp,
  #....
  storage_connector: ExFTP.Storage.FileConnector,
  storage_config: %{}
```

[^ top](#top)

-------

### Storage Connector: S3

When **storage_connector** is `ExFTP.Storage.S3Connector`, this connector will use any S3-compatible storage provider.

Underneath the hood, ex_ftp is using `ExAws.S3`, so you'll need that configured properly.

```elixir
# ExAws is pretty smart figuring out S3 credentials of the system
# For me, I had to include the region.
# Consult the ExAws docs for more
config :ex_aws,
  region: {:system, "AWS_REGION"}

config :ex_ftp,
  #....
  storage_connector: ExFTP.Storage.S3Connector,
  storage_config: %{
    # the `/` path of the FTP server will point to s3://{my-storage-bucket}/
    storage_bucket: "my-storage-bucket"
  }
```

#### Using Minio or LocalStack

Minio is a popular open-source, self-hosted alternative to AWS S3. 

LocalStack is a popular way to test AWS without connecting to AWS.

The only difference in config will be how you configure `ExAws`.

Here's an example with minio where we're changing the credentials and endpoint

```elixir
# Assuming:
#   we're connecting to a minio @ https://my.minio.example.com:9000/
#   there exists a $MINIO_ACCESS or $AWS_ACCESS_KEY_ID in system env
#   there exists a $MINIO_SECRET or $AWS_SECRET_ACCESS_KEY in system env
config :ex_aws,
  access_key_id: [
    {:system, "MINIO_ACCESS"},
    {:system, "AWS_ACCESS_KEY_ID"},
    :instance_role
  ],
  secret_access_key: [
    {:system, "MINIO_SECRET"},
    {:system, "AWS_SECRET_ACCESS_KEY"},
    :instance_role
  ],
  s3: [
    scheme: "https://",
    host: "my.minio.example.com",
    port: 9000,
    region: "us-east-1"
  ]

config :ex_ftp,
  #....
  storage_connector: ExFTP.Storage.S3Connector,
  storage_config: %{
    # the `/` path of the FTP server will point to s3://{my-storage-bucket}/
    storage_bucket: "my-storage-bucket"
  }
```

[^ top](#top)


-------

### Storage Connector: Others through S3Proxy

For other storage providers (Google Cloud, Azure Storage, etc.), it's probably best to deploy a proxy that translates
S3 requests into requests to those providers, then use the `ExFTP.Storage.S3Connector` to connect to that proxy.

* See [S3Proxy](https://github.com/gaul/s3proxy?tab=readme-ov-file)

[^ top](#top)

-------

### Custom Storage Connector

Creating your own Storage Connector is simple - just implement the `ExFTP.StorageConnector` behaviour.

```elixir
# SPDX-License-Identifier: Apache-2.0
defmodule MyStorageConnector do
  @moduledoc false

  @behaviour ExFTP.StorageConnector

  alias ExFTP.StorageConnector

  @impl StorageConnector
  @spec get_working_directory(connector_state :: StorageConnector.connector_state()) ::
          String.t()
  def get_working_directory(%{current_working_directory: cwd} = _connector_state) do
    # returns the current directory, for most cases this is just a pass through
    # however, you might want to modify what the current directory is
    # based on some state
  end

  @impl StorageConnector
  @spec directory_exists?(
          path :: StorageConnector.path(),
          connector_state :: StorageConnector.connector_state()
        ) :: boolean
  def directory_exists?(path, _connector_state) do
    # Given a path, does this directory exist in storage?
  end

  @impl StorageConnector
  @spec make_directory(
          path :: StorageConnector.path(),
          connector_state :: StorageConnector.connector_state()
        ) :: {:ok, StorageConnector.connector_state()} | {:error, term()}
  def make_directory(path, connector_state) do
    # Given a path, make a directory
    # For S3-like connectors, a "directory" doesn't really exist
    #  so those connectors typically keep track of virtual directories
    #  that we're created by user during the session
    #  if they're unused, they aren't persisted.
  end

  @impl StorageConnector
  @spec delete_directory(
          path :: StorageConnector.path(),
          connector_state :: StorageConnector.connector_state()
        ) :: {:ok, StorageConnector.connector_state()} | {:error, term()}
  def delete_directory(path, connector_state) do
    # Give a path, delete the directory
  end

  @impl StorageConnector
  @spec delete_file(
          path :: StorageConnector.path(),
          connector_state :: StorageConnector.connector_state()
        ) :: {:ok, StorageConnector.connector_state()} | {:error, term()}
  def delete_file(path, connector_state) do
    # Give a path, delete the file
  end

  @impl StorageConnector
  @spec get_directory_contents(
          path :: StorageConnector.path(),
          connector_state :: StorageConnector.connector_state()
        ) ::
          {:ok, [StorageConnector.content_info()]} | {:error, term()}
  def get_directory_contents(path, connector_state) do
    # returns a list of content_infos
    # the model for them was inspired by File.lstat()
    # Have a look at StorageConnector.content_info type
  end

  @impl StorageConnector
  @spec get_content_info(
          path :: StorageConnector.path(),
          connector_state :: StorageConnector.connector_state()
        ) ::
          {:ok, StorageConnector.content_info()} | {:error, term()}
  def get_content_info(path, _connector_state) do
    # given a path, return information on the file/directory there
    # Have a look at StorageConnector.content_info type
  end

  @impl StorageConnector
  @spec get_content(
          path :: StorageConnector.path(),
          connector_state :: StorageConnector.connector_state()
        ) :: {:ok, any()} | {:error, term()}
  def get_content(path, _connector_state) do
    # Return a {:ok, stream} of path
  end

  @impl StorageConnector
  @spec create_write_func(
          path :: StorageConnector.path(),
          connector_state :: StorageConnector.connector_state(),
          opts :: list()
        ) :: function()
  def create_write_func(path, connector_state, opts \\ []) do
    # Return a function that will write `stream` to your storage at path
    # e.g 
    # fn stream ->
    #  fs = File.stream!(path)
    #
    #  try do
    #    _ =
    #      stream
    #      |> chunk_stream(opts)
    #      |> Enum.into(fs)
    #
    #    {:ok, connector_state}
    #  rescue
    #    _ ->
    #      {:error, "Failed to transfer"}
    #  end
    #end
  end
end
```

#### User-Aware Storage Connectors

After successful authentication, the `connector_state` will contain an `authenticator_state` key with the authenticated user's information. This allows you to create storage connectors that scope access based on the logged-in user.

**Example: User-Scoped File Access**

```elixir
defmodule MyApp.UserScopedConnector do
  @behaviour ExFTP.StorageConnector

  @impl StorageConnector
  @spec get_content(
          path :: StorageConnector.path(),
          connector_state :: StorageConnector.connector_state()
        ) :: {:ok, any()} | {:error, term()}
  def get_content(path, %{authenticator_state: auth_state} = connector_state) do
    # Access the authenticated user's username
    # username = auth_state.username

    # Scope all file access to the user's directory
    # scoped_path = Path.join(["/users", username, path])
  end

  # All other callbacks receive authenticator_state in connector_state
  # and can implement user-specific logic similarly
end
```

The `authenticator_state` will always be present when your storage connector callbacks are invoked, containing:
- `username` - The authenticated username
- Any custom fields your authenticator added (e.g., permissions, user metadata)

[^ top](#top)

-------

## Technical Details

### Supported Commands

- General
  - `QUIT`
  - `SYST`
  - `TYPE <mode>`
  - `PASV`
  - `EPSV`
  - `EPRT <eport_info>`
- Auth
  - `USER <username>`
  - `PASS <password>`
- Storage 
  - `PWD`
  - `CDUP`
  - `CWD <path>`
  - `MKD <path>`
  - `RMD <path>`
  - `DELE <path>`
  - `LIST`
    - `LIST -a`
    - `LIST -a <path>`
    - `LIST <path>`
  - `NLST`
    - `NLST -a`
    - `NLST -a <path>`
    - `NLST <path>`
  - `RETR <path>`
  - `SIZE <path>`
  - `STOR <path>`

See `ExFTP.Storage.Common` for more information.


### Notes about Fly.io

If you're wanting to deploy onto Fly.io, you'll quickly discover an issue with passive ports.

Fly wants you to enumerate all ports that your server will use, fine; however, it takes the assumption
that these ports will be open *on start* and will *remain* open. 

FTP passive ports are temporary and negotiated. Fly hates this and assumes something is going wrong.

Be careful.

[^ top](#top)

-----

## Special Thanks

The initial funding for this code came from [StudioCMS.io](https://studiocms.io/).

Its first closed-source implementation came from [Jake Stover](https://github.com/jwstover) and expanded by the 
entire team at StudioCMS.

Furthermore, StudioCMS's leadership allowed me to clean it up, generalize it, and open source it.

Thanks!

[^ top](#top)
