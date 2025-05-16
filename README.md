<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/camatcode/ex_ftp/refs/heads/main/assets/ex_ftp-logo-dark.png">
    <source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/camatcode/ex_ftp/refs/heads/main/assets/ex_ftp-logo-light.png">
    <img alt="basenji logo" src="https://raw.githubusercontent.com/camatcode/ex_ftp/refs/heads/main/assets/ex_ftp-logo-light.png" width="320">
  </picture>
</p>

<p align="center">
  Serve an FTP interface that connects locally, to the cloud, or wherever
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

<p align="center">
  An extendable, lightweight FTP server with cloud integrations already built in
</p>


## Table of Contents

- [Installation](#installation)
- [Reckless Quick Start](#reckless-quick-start)
- [Configuration](#configuration)
  - [Choosing an Authenticator](#choosing-an-authenticator)
    - [No Auth](#no-auth)
    - [Passthrough Auth](#passthrough-auth)
    - [HTTP Basic Auth](#http-basic-auth)
    - [HTTP Digest Access Auth](#http-digest-access-auth)
    - [Bearer Token Auth](#bearer-token-auth)
    - [Webhook Auth](#webhook-auth)
    - [Custom Auth](#custom-auth)
  - [Choosing a Storage Connector](#choosing-a-storage-connector)
      - [File Storage Connector](#file-storage-connector)
      - [S3 Connector](#s3-storage-connector)
          - [Using Minio](#using-minio)
      - [Google Cloud Storage Connector](#google-cloud-storage-connector)
      - [Azure Storage Connector](#azure-storage-connector)
      - [Supabase Storage Connector](#supabase-storage-connector)
      - [Custom Storage Connector](#custom-storage-connector)

### Installation

Add `:ex_ftp` to your list of deps in `mix.exs`:

```elixir
{:ex_ftp, "~> 1.0"}
```

Then run `mix deps.get` to install ExFTP and its dependencies.





### Reckless Quick Start

TODO

### Configuration

#### Choosing an Authenticator

An `ExFTP.Authenticator` validates credentials when an FTP client sends a `USER` and `PASSWORD` command.

Each authenticator is referenced in the `ex_ftp` config under the `authenticator` key. 

Additionally, many require an additional map under `authenticator_config`.

##### No Auth

When `authenticator` is `ExFTP.Auth.NoAuth`, ex_ftp will completely ignore any supplied credentials and assume
everything is authenticated.

This is not recommended for any production server.

```elixir
     config :ex_ftp,
       #....
       authenticator: ExFTP.Auth.NoAuth,
       authenticator_config: %{}
 ```

##### Passthrough Auth

When `authenticator` is `ExFTP.Auth.PassthroughAuth`, ex_ftp will require credentials, 
but accept any user and password combination who isn't `root`.

This is not recommended for any production server.

```elixir
     config :ex_ftp,
       #....
       authenticator: ExFTP.Auth.PassthroughAuth,
       authenticator_config: %{}
 ```

##### HTTP Basic Auth

When `authenticator` is `ExFTP.Auth.BasicAuth`, ex_ftp call out to an HTTP endpoint that implements 
[HTTP Basic Auth](https://en.wikipedia.org/wiki/Basic_access_authentication). 

If the endpoint responds with **HTTP 200**, the user is considered authenticated.

Additionally, if configured, ex_ftp can call out to a separate endpoint that performs basic auth to check that a user
is still considered valid.

This is not recommended for situations not protected by SSL.

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
          authenticated_ttl_ms: 1000 * 60 * 30
      }
 ```

##### HTTP Digest Access Auth

When `authenticator` is `ExFTP.Auth.DigestAuth`, ex_ftp call out to an HTTP endpoint that implements
[HTTP Digest Access Auth](https://en.wikipedia.org/wiki/Digest_access_authentication).

If, after completing the full workflow, the endpoint responds with **HTTP 200**, the user is considered authenticated.

Additionally, if configured, ex_ftp can call out to a separate endpoint that performs digest auth to check that a user
is still considered valid.

This can be used in situations where SSL is not available, though be warned, it is considered obsolete.

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
          authenticated_ttl_ms: 1000 * 60 * 30
      }
 ```

##### Bearer Token Auth

When `authenticator` is `ExFTP.Auth.BearerAuth`, ex_ftp call out to an HTTP endpoint that implements
[Bearer Tokens](https://swagger.io/docs/specification/v3_0/authentication/bearer-authentication/). 

Note that `username` isn't important for a Bearer token; though a provided username is still held on to.

If the endpoint responds with **HTTP 200**, the user is considered authenticated.

Additionally, if configured, ex_ftp can call out to a separate endpoint that performs bearer auth to check that a user
is still considered valid.

This is helpful when the "user" is actually a system or process.

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
          authenticated_ttl_ms: 1000 * 60
      }
 ```

##### Webhook Auth

When `authenticator` is `ExFTP.Auth.WebhookAuth`, ex_ftp call out to an HTTP endpoint that accepts
two query parameters: `username` and `password_hash`.

`password_hash` is the hash of the supplied password using the hashing algorithm dictated by the config.

If the endpoint responds with **HTTP 200**, the user is considered authenticated.

Additionally, if configured, ex_ftp can call out to a separate endpoint that performs webhook auth to check that a user
is still considered valid.

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
            authenticated_ttl_ms: 1000 * 60
      }
 ```

##### Custom Auth

Creating your own Authenticator is simple - just implement the `ExFTP.Authenticator` behaviour.

```elixir
# SPDX-License-Identifier: Apache-2.0
defmodule MyCustomAuth do

  alias ExFTP.Authenticator
  @behaviour Authenticator

  @impl Authenticator
  @spec valid_user?(username :: Authenticator.username()) :: boolean
  def valid_user?(_username) do
        # return true if the username is valid
        # return false if invalid
        # this short-circuits login requests,
        # if it would take longer than 5 seconds to validate a username
        #   then its best to just return true
        #   as there wouldn't be a performance benefit
  end

  @impl Authenticator
  @spec login(
          password :: Authenticator.password(),
          authenticator_state :: Authenticator.authenticator_state()
        ) :: {:ok, Authenticator.authenticator_state()} | {:error, term()}
  def login(_password, authenticator_state) do
        # perform initial login
        # return {:ok, current_authenticator_state} if successful
        #   authenticator_state is passed around during the session
        # return {:error, anything} if unsuccessful
  end

  @impl Authenticator
  @spec authenticated?(authenticator_state :: Authenticator.authenticator_state()) :: boolean()
  def authenticated?(_authenticator_state), do
        # re-check that a user is authenticated
        # return {:ok, current_authenticator_state} if successful
        #   authenticator_state is passed around during the session
        # return {:error, anything} if unsuccessful
  end
end
```

#### Choosing a Storage Connector

##### File Storage Connector

##### S3 Storage Connector

###### Using Minio

##### Google Cloud Storage Connector

##### Azure Storage Connector

##### Supabase Storage Connector

##### Custom Storage Connector
