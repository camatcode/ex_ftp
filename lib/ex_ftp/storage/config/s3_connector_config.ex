# SPDX-License-Identifier: Apache-2.0
defmodule ExFTP.Storage.S3ConnectorConfig do
  @moduledoc """
  A module describing the **authenticator_config** value for `ExFTP.Storage.S3Connector`

  <!-- tabs-open -->

  #{ExFTP.Doc.related(["`ExFTP.Storage.S3Connector`", "`ExFTP.StorageConnector`"])}

  #{ExFTP.Doc.resources()}

  <!-- tabs-close -->
  """
  import ExFTP.Storage.Common

  alias ExFTP.Storage.S3ConnectorConfig

  @typedoc """
  A bucket to use as the root directory of the FTP server.

  If undefined, all buckets will be under the root.
  """
  @type storage_bucket :: String.t() | nil

  @typedoc """
  The **storage_config** value for `ExFTP.Storage.S3Connector`

  <!-- tabs-open -->

  ### 🏷️ Optional Keys
    * **storage_bucket** :: `t:ExFTP.Storage.S3ConnectorConfig.storage_bucket/0`

  <!-- tabs-open -->
  """
  @type t() :: %S3ConnectorConfig{
          storage_bucket: storage_bucket()
        }

  defstruct [
    :storage_bucket
  ]

  @doc """
  Builds a `t:ExFTP.Storage.S3ConnectorConfig.t/0` from a map

  <!-- tabs-open -->

  ### 🏷️ Params
    * **m** :: A map to build into a `t:ExFTP.Storage.S3ConnectorConfig.t/0`

  <!-- tabs-close -->
  """
  @spec build(m :: map) :: S3ConnectorConfig.t()
  def build(m) do
    fields =
      m
      |> prepare()

    struct(ExFTP.Storage.S3ConnectorConfig, fields)
  end
end
