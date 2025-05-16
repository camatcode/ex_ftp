# SPDX-License-Identifier: Apache-2.0
defmodule ExFTP.Storage.S3ConnectorConfig do
  @moduledoc false

  import ExFTP.Storage.Common

  alias ExFTP.Storage.S3ConnectorConfig
  @type storage_bucket :: String.t()

  @type t() :: %S3ConnectorConfig{
          storage_bucket: storage_bucket()
        }

  defstruct [
    :storage_bucket
  ]

  def build(m) do
    fields =
      m
      |> prepare()

    struct(ExFTP.Storage.S3ConnectorConfig, fields)
  end
end
