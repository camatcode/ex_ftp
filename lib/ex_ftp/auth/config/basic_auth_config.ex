# SPDX-License-Identifier: Apache-2.0
defmodule ExFTP.Auth.BasicAuthConfig do
  @moduledoc """
  A module describing the **authenticator_config** value for `ExFTP.Auth.BasicAuth`

  <!-- tabs-open -->

  #{ExFTP.Doc.related(["`ExFTP.Auth.BasicAuth`", "`ExFTP.Authenticator`"])}

  #{ExFTP.Doc.resources()}

  <!-- tabs-close -->
  """
  import ExFTP.Auth.Common

  alias ExFTP.Auth.BasicAuthConfig
  alias ExFTP.Auth.Common

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
  @type t() :: %BasicAuthConfig{
          authenticated_ttl_ms: Common.authenticated_ttl_ms(),
          login_url: Common.login_url(),
          login_method: Common.login_method(),
          authenticated_url: Common.authenticated_url() | nil,
          authenticated_method: Common.authenticated_method()
        }

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
