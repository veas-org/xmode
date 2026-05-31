import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "preview"]

  connect() {
    this.refresh()
  }

  bold() {
    this.wrapSelection("**", "**", "bold text")
  }

  italic() {
    this.wrapSelection("_", "_", "italic text")
  }

  list() {
    this.prefixLines("- ")
  }

  quote() {
    this.prefixLines("> ")
  }

  code() {
    this.wrapSelection("```\n", "\n```", "code")
  }

  togglePreview() {
    this.previewTarget.classList.toggle("hidden")
    this.refresh()
  }

  refresh() {
    if (!this.hasPreviewTarget) return

    this.previewTarget.innerHTML = this.renderMarkdown(this.inputTarget.value)
  }

  wrapSelection(before, after, fallback) {
    const input = this.inputTarget
    const start = input.selectionStart
    const end = input.selectionEnd
    const selection = input.value.slice(start, end) || fallback
    const replacement = `${before}${selection}${after}`

    input.setRangeText(replacement, start, end, "select")
    input.focus()
    this.refresh()
  }

  prefixLines(prefix) {
    const input = this.inputTarget
    const start = input.selectionStart
    const end = input.selectionEnd
    const selection = input.value.slice(start, end) || "List item"
    const replacement = selection
      .split("\n")
      .map((line) => line.startsWith(prefix) ? line : `${prefix}${line}`)
      .join("\n")

    input.setRangeText(replacement, start, end, "select")
    input.focus()
    this.refresh()
  }

  renderMarkdown(markdown) {
    const blocks = this.escape(markdown).split(/\n{2,}/).map((block) => this.renderBlock(block.trim())).filter(Boolean)
    return blocks.length ? blocks.join("") : "<p></p>"
  }

  renderBlock(block) {
    if (!block) return ""
    if (block.startsWith("```")) return `<pre><code>${block.replace(/^```[a-z]*\n?/i, "").replace(/```$/, "")}</code></pre>`
    if (block.startsWith("# ")) return `<h1>${this.inline(block.slice(2))}</h1>`
    if (block.startsWith("## ")) return `<h2>${this.inline(block.slice(3))}</h2>`
    if (block.startsWith("### ")) return `<h3>${this.inline(block.slice(4))}</h3>`
    if (block.split("\n").every((line) => line.startsWith("- "))) {
      return `<ul>${block.split("\n").map((line) => `<li>${this.inline(line.slice(2))}</li>`).join("")}</ul>`
    }
    if (block.split("\n").every((line) => line.startsWith("> "))) {
      return `<blockquote>${block.split("\n").map((line) => this.inline(line.slice(2))).join("<br>")}</blockquote>`
    }

    return `<p>${this.inline(block).replace(/\n/g, "<br>")}</p>`
  }

  inline(text) {
    return text
      .replace(/`([^`]+)`/g, "<code>$1</code>")
      .replace(/\*\*([^*]+)\*\*/g, "<strong>$1</strong>")
      .replace(/_([^_]+)_/g, "<em>$1</em>")
  }

  escape(value) {
    return value
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#39;")
  }
}
