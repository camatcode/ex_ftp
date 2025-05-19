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
  - [Supabase Storage](#storage-connector-supabase)
  - [Others through S3Proxy](#storage-connector-others-through-s3proxy)
  - [Custom Storage Connector](#custom-storage-connector)

## Installation

Add `:ex_ftp` to your list of deps in `mix.exs`:

```elixir
{:ex_ftp, "~> 1.0"}
```

Then run `mix deps.get` to install ExFTP and its dependencies.

## Reckless Quick Start

🚧 TODO

## Configuration

### 1. Server Config

Here is a detailed, example configuration.

```elixir
config :ex_ftp,
  # port to run on
  ftp_port: 21,
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
  #....
  authenticator: ExFTP.Auth.DigestAuth,
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
        # return {:ok, current_authenticator_state} if successful
        #   authenticator_state is passed around during the session
        # return {:error, anything} if unsuccessful
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

### Storage Connector: Supabase

🚧 TODO

[^ top](#top)

-------

### Storage Connector: Others through S3Proxy

For other storage providers (Google Cloud, Azure Storage, etc.), it's probably best to deploy a proxy that translates
S3 requests into requests to those providers, then use the `ExFTP.Storage.S3Connector` to connect to that proxy.

* See [S3Proxy](https://github.com/gaul/s3proxy?tab=readme-ov-file)

[^ top](#top)

-------

### Custom Storage Connector

🚧 TO document.

[^ top](#top)

-------