defmodule ExFTP.Doc do
  @moduledoc false

  def maintainer_github,
    do: "👾 [Github: camatcode](https://github.com/camatcode/){:target=\"_blank\"}"

  def maintainer_fediverse,
    do:
      "🐘 [Fediverse: @scrum_log@maston.social](https://mastodon.social/@scrum_log){:target=\"_blank\"}"

  def contact_maintainer, do: "💬 Contact the maintainer (he's happy to help!)"

  def resources(doc_reference \\ nil) do
    "### 📖 Resources
  * #{see_rfc(doc_reference)}
  * #{contact_maintainer()}
    * #{maintainer_github()}
    * #{maintainer_fediverse()}
    "
  end

  def related(related_list) do
    header = "### 👀 See Also "

    related_block =
      related_list
      |> Enum.map_join("\n", fn related ->
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

  def see_rfc(nil) do
    see_link(
      "RFC 959",
      "https://www.rfc-editor.org/rfc/rfc959"
    )
  end

  def see_rfc(doc_reference) do
    see_link(
      "RFC 959 (#{doc_reference})",
      "https://www.rfc-editor.org/rfc/rfc959##{doc_reference}"
    )
  end

  def see_link(title, url) do
    "📖 [#{title}](#{url}){:target=\"_blank\"}"
  end
end
