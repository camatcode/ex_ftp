# SPDX-License-Identifier: Apache-2.0
defmodule ExFTP.Auth.BearerAuthConfig do
  @moduledoc """
  A module describing the **authenticator_config** value for `ExFTP.Auth.BearerAuth`

  <!-- tabs-open -->

  #{ExFTP.Doc.related(["`ExFTP.Auth.BearerAuth`", "`ExFTP.Authenticator`"])}

  #{ExFTP.Doc.resources()}

  <!-- tabs-close -->
  """
  import ExFTP.Auth.Common

  alias ExFTP.Auth.BearerAuthConfig

  @typedoc """
  The **authenticator_config** value for `ExFTP.Auth.WebhookAuth`

  <!-- tabs-open -->
  ### 🏷️ Required Keys
    * **login_url** :: `t:login_url/0`

  ### 🏷️ Optional Keys
    * **login_method** :: `t:login_method/0`
    * **password_hash_type** :: `t:password_hash_type/0`
    * **authenticated_url** :: `t:authenticated_url/0`
    * **authenticated_method** :: `t:authenticated_url/0`
    * **authenticated_ttl_ms** :: `t:authenticated_ttl_ms/0`

  <!-- tabs-open -->
  """
  @type t() :: %BearerAuthConfig{
          authenticated_ttl_ms: authenticated_ttl_ms(),
          login_url: login_url(),
          login_method: login_method(),
          authenticated_url: authenticated_url() | nil,
          authenticated_method: authenticated_method()
        }

  @typedoc """
  A URL used by `ExFTP.Auth.BearerAuth.authenticated?/1` to check if a user should still be considered authenticated

  <!-- tabs-open -->

  #{ExFTP.Doc.related(["`ExFTP.Auth.BearerAuth.authenticated?/1`"])}

  <!-- tabs-close -->
  """
  @type authenticated_url :: URI.t() | String.t()

  @typedoc """
  Paired with `t:authenticated_url/0`

  <!-- tabs-open -->

  #{ExFTP.Doc.related(["`ExFTP.Auth.BearerAuth.authenticated?/1`"])}

  <!-- tabs-close -->
  """
  @type authenticated_method :: http_method()

  @typedoc """
  How many milliseconds pass before a user's session is not assumed still-authenticated.

  <!-- tabs-open -->

  #{ExFTP.Doc.related(["`ExFTP.Auth.BearerAuth.authenticated?/1`"])}

  <!-- tabs-close -->
  """
  @type authenticated_ttl_ms :: integer()

  @typedoc """
  A URL used by `ExFTP.Auth.BearerAuth.login/2` to log in a user

  <!-- tabs-open -->

  #{ExFTP.Doc.related(["`ExFTP.Auth.BearerAuth.login/2`"])}

  <!-- tabs-close -->
  """
  @type login_url :: URI.t() | String.t()

  @typedoc """
  Paired with `t:login_url/0`

  <!-- tabs-open -->

  #{ExFTP.Doc.related(["`ExFTP.Auth.BearerAuth.login/2`"])}

  <!-- tabs-close -->
  """
  @type login_method :: http_method()

  @typedoc """
  An HTTP method to use in a request.

  <!-- tabs-open -->

  #{ExFTP.Doc.related(["`ExFTP.Auth.BearerAuth.authenticated?/1`", "`ExFTP.Auth.BearerAuth.login/2`"])}

  <!-- tabs-close -->
  """
  @type http_method ::
          :get | :head | :post | :put | :connect | :delete | :options | :trace | :patch

  @enforce_keys [:login_url]

  defstruct [
    :login_url,
    :authenticated_url,
    :authenticated_ttl_ms,
    login_method: :get,
    authenticated_method: :get
  ]

  def build(m) do
    fields =
      m
      |> prepare()

    struct(ExFTP.Auth.BearerAuthConfig, fields)
  end
end
