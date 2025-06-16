# SPDX-License-Identifier: Apache-2.0
defmodule ExFTP.Doc do
  @moduledoc false

  def maintainer_github, do: "👾 [Github: camatcode](https://github.com/camatcode/){:target=\"_blank\"}"

  def maintainer_fediverse,
    do: "🐘 [Fediverse: @scrum_log@maston.social](https://mastodon.social/@scrum_log){:target=\"_blank\"}"

  def contact_maintainer, do: "💬 Contact the maintainer (he's happy to help!)"

  def resources(rfc_959_ref \\ nil, rfc_3659_ref \\ nil) do
    "### 📖 Resources
  * #{see_rfc_959(rfc_959_ref)}
  * #{see_rfc_3659(rfc_3659_ref)}
  * #{contact_maintainer()}
    * #{maintainer_github()}
    * #{maintainer_fediverse()}
    "
  end

  def related(related_list) do
    header = "### 👀 See Also "

    related_block =
      Enum.map_join(related_list, "\n", fn related ->
        "  * #{related}"
      end)

    """
    #{header}
    #{related_block}
    """
  end

  def returns(success: success, failure: failure) do
    "### ⤵️ Returns

  **✅ On Success**

  ```elixir
  #{success}
  ```
  **❌ On Failure**

   ```elixir
  #{failure}
  ```"
  end

  def returns(success: success) do
    "### ⤵️ Returns

  **✅ On Success**

  ```elixir
  #{success}
  ```
  "
  end

  def readme do
    "README.md" |> File.read!() |> String.replace("(#", "(#module-")
  end

  def see_rfc_959(nil) do
    see_link(
      "RFC 959",
      "https://www.rfc-editor.org/rfc/rfc959"
    )
  end

  def see_rfc_959(doc_reference) do
    see_link(
      "RFC 959 (#{doc_reference})",
      "https://www.rfc-editor.org/rfc/rfc959##{doc_reference}"
    )
  end

  def see_rfc_3659(nil) do
    see_link(
      "RFC 3659",
      "https://www.rfc-editor.org/rfc/rfc3659"
    )
  end

  def see_rfc_3659(doc_reference) do
    see_link(
      "RFC 3659 (#{doc_reference})",
      "https://www.rfc-editor.org/rfc/3659##{doc_reference}"
    )
  end

  def see_link(title, url) do
    "📖 [#{title}](#{url}){:target=\"_blank\"}"
  end
end
