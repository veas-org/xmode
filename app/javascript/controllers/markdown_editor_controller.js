import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "editor", "input", "preview", "previewButton", "sourceButton"]
  static values = { placeholder: String }

  connect() {
    this.sourceMode = false
    this.previewVisible = this.hasPreviewTarget && !this.previewTarget.classList.contains("hidden")
    this.tiptapReady = false
    this.refresh()
    this.bootTiptap()
  }

  disconnect() {
    this.editor?.destroy()
  }

  async bootTiptap() {
    if (!this.hasEditorTarget) return

    try {
      const [{ Editor }, { default: StarterKit }, { default: Link }, { default: Placeholder }, { marked }, { default: TurndownService }] = await Promise.all([
        import("@tiptap/core"),
        import("@tiptap/starter-kit"),
        import("@tiptap/extension-link"),
        import("@tiptap/extension-placeholder"),
        import("marked"),
        import("turndown")
      ])

      this.marked = marked
      this.turndown = new TurndownService({
        bulletListMarker: "-",
        codeBlockStyle: "fenced",
        headingStyle: "atx"
      })

      this.editor = new Editor({
        element: this.editorTarget,
        extensions: [
          StarterKit,
          Link.configure({ autolink: true, openOnClick: false }),
          Placeholder.configure({ placeholder: this.placeholderValue || "" })
        ],
        content: this.markdownToHtml(this.inputTarget.value),
        editorProps: {
          attributes: {
            class: "tiptap-content rich-markdown"
          }
        },
        onUpdate: ({ editor }) => {
          if (this.sourceMode) return

          this.inputTarget.value = this.htmlToMarkdown(editor.getHTML())
          this.inputTarget.dispatchEvent(new Event("input", { bubbles: true }))
          this.refresh()
          this.updateToolbar()
        },
        onSelectionUpdate: () => this.updateToolbar(),
        onFocus: () => this.updateToolbar()
      })

      this.tiptapReady = true
      this.element.dataset.markdownEditorMode = "rich"
      this.editorTarget.classList.remove("hidden")
      this.inputTarget.classList.add("hidden")
      this.updateToolbar()
    } catch {
      this.tiptapReady = false
      this.element.dataset.markdownEditorMode = "source"
      this.sourceMode = true
      this.updateToolbar()
    }
  }

  bold() {
    if (this.runCommand((editor) => editor.chain().focus().toggleBold().run())) return

    this.wrapSelection("**", "**", "bold text")
  }

  undo() {
    if (this.runCommand((editor) => editor.chain().focus().undo().run())) return
  }

  redo() {
    if (this.runCommand((editor) => editor.chain().focus().redo().run())) return
  }

  italic() {
    if (this.runCommand((editor) => editor.chain().focus().toggleItalic().run())) return

    this.wrapSelection("_", "_", "italic text")
  }

  heading() {
    if (this.runCommand((editor) => editor.chain().focus().toggleHeading({ level: 2 }).run())) return

    this.prefixLines("## ")
  }

  list() {
    if (this.runCommand((editor) => editor.chain().focus().toggleBulletList().run())) return

    this.prefixLines("- ")
  }

  orderedList() {
    if (this.runCommand((editor) => editor.chain().focus().toggleOrderedList().run())) return

    this.numberLines()
  }

  quote() {
    if (this.runCommand((editor) => editor.chain().focus().toggleBlockquote().run())) return

    this.prefixLines("> ")
  }

  code() {
    if (this.runCommand((editor) => editor.chain().focus().toggleCodeBlock().run())) return

    this.wrapSelection("```\n", "\n```", "code")
  }

  horizontalRule() {
    if (this.runCommand((editor) => editor.chain().focus().setHorizontalRule().run())) return

    this.insertMarkdown("---")
  }

  snippet(event) {
    const markdown = this.templateFor(event.currentTarget.dataset.template)
    if (!markdown) return

    this.insertMarkdown(markdown)
  }

  link() {
    if (!this.tiptapReady) {
      this.wrapSelection("[", "](https://example.com)", "link text")
      return
    }

    const previousUrl = this.editor.getAttributes("link").href
    const url = window.prompt("Link URL", previousUrl || "https://")
    if (url === null) return
    if (url === "") {
      this.editor.chain().focus().extendMarkRange("link").unsetLink().run()
    } else {
      this.editor.chain().focus().extendMarkRange("link").setLink({ href: url }).run()
    }
  }

  toggleSource() {
    if (!this.tiptapReady) return

    this.sourceMode = !this.sourceMode
    if (this.sourceMode) {
      this.element.dataset.markdownEditorMode = "source"
      this.inputTarget.classList.remove("hidden")
      this.editorTarget.classList.add("hidden")
      this.inputTarget.focus()
    } else {
      this.element.dataset.markdownEditorMode = "rich"
      this.editor.commands.setContent(this.markdownToHtml(this.inputTarget.value), false)
      this.inputTarget.classList.add("hidden")
      this.editorTarget.classList.remove("hidden")
      this.editor.commands.focus()
      this.updateToolbar()
    }
    this.refresh()
  }

  togglePreview() {
    this.previewVisible = this.previewTarget.classList.toggle("hidden") === false
    this.refresh()
    this.updateToolbar()
  }

  refresh() {
    if (!this.hasPreviewTarget) return

    this.previewTarget.innerHTML = this.renderPreview(this.inputTarget.value)
  }

  runCommand(callback) {
    if (!this.tiptapReady || this.sourceMode) return false

    callback(this.editor)
    this.updateToolbar()
    return true
  }

  insertMarkdown(markdown) {
    if (this.tiptapReady && !this.sourceMode) {
      this.editor.chain().focus().insertContent(this.markdownToHtml(markdown)).run()
      this.inputTarget.value = this.htmlToMarkdown(this.editor.getHTML())
      this.inputTarget.dispatchEvent(new Event("input", { bubbles: true }))
      this.refresh()
      this.updateToolbar()
      return
    }

    const input = this.inputTarget
    const start = input.selectionStart
    const end = input.selectionEnd
    const before = input.value.slice(0, start)
    const after = input.value.slice(end)
    const prefix = before.length > 0 && !before.endsWith("\n\n") ? before.endsWith("\n") ? "\n" : "\n\n" : ""
    const suffix = after.length > 0 && !after.startsWith("\n\n") ? after.startsWith("\n") ? "\n" : "\n\n" : ""
    const replacement = `${prefix}${markdown.trim()}${suffix}`

    input.setRangeText(replacement, start, end, "end")
    input.focus()
    input.dispatchEvent(new Event("input", { bubbles: true }))
    this.refresh()
  }

  templateFor(template) {
    switch (template) {
      case "objective":
        return "## Objective\n\nDescribe the target outcome, constraints, and evidence for done."
      case "plan":
        return "## Plan\n\n1. Confirm the context and required inputs.\n2. Execute the smallest safe change.\n3. Verify the result and capture evidence."
      case "acceptance":
        return "## Acceptance\n\n- Behavior is verified.\n- Evidence is attached.\n- Follow-up risk is captured."
      default:
        return null
    }
  }

  updateToolbar() {
    if (this.hasSourceButtonTarget) {
      this.sourceButtonTarget.classList.toggle("is-active", this.sourceMode)
      this.sourceButtonTarget.setAttribute("aria-pressed", this.sourceMode.toString())
    }

    if (this.hasPreviewButtonTarget) {
      this.previewButtonTarget.classList.toggle("is-active", this.previewVisible)
      this.previewButtonTarget.setAttribute("aria-pressed", this.previewVisible.toString())
    }

    if (!this.tiptapReady || !this.hasButtonTarget) return

    this.buttonTargets.forEach((button) => {
      const format = button.dataset.format
      const active = !this.sourceMode && this.formatActive(format)
      button.classList.toggle("is-active", active)
      button.setAttribute("aria-pressed", active.toString())
    })
  }

  formatActive(format) {
    switch (format) {
      case "heading":
        return this.editor.isActive("heading", { level: 2 })
      case "bulletList":
        return this.editor.isActive("bulletList")
      case "orderedList":
        return this.editor.isActive("orderedList")
      case "blockquote":
        return this.editor.isActive("blockquote")
      case "codeBlock":
        return this.editor.isActive("codeBlock")
      case "link":
        return this.editor.isActive("link")
      default:
        return this.editor.isActive(format)
    }
  }

  markdownToHtml(markdown) {
    if (this.marked) return this.marked.parse(markdown || "")

    return this.renderMarkdown(markdown)
  }

  htmlToMarkdown(html) {
    return this.turndown.turndown(html).trim()
  }

  wrapSelection(before, after, fallback) {
    const input = this.inputTarget
    const start = input.selectionStart
    const end = input.selectionEnd
    const selection = input.value.slice(start, end) || fallback
    const replacement = `${before}${selection}${after}`

    input.setRangeText(replacement, start, end, "select")
    input.focus()
    input.dispatchEvent(new Event("input", { bubbles: true }))
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
    input.dispatchEvent(new Event("input", { bubbles: true }))
    this.refresh()
  }

  numberLines() {
    const input = this.inputTarget
    const start = input.selectionStart
    const end = input.selectionEnd
    const selection = input.value.slice(start, end) || "List item"
    const replacement = selection
      .split("\n")
      .map((line, index) => line.match(/^\d+\.\s/) ? line : `${index + 1}. ${line}`)
      .join("\n")

    input.setRangeText(replacement, start, end, "select")
    input.focus()
    input.dispatchEvent(new Event("input", { bubbles: true }))
    this.refresh()
  }

  renderPreview(markdown) {
    return this.sanitizeHtml(this.markdownToHtml(markdown))
  }

  renderMarkdown(markdown) {
    const blocks = this.escape(markdown).split(/\n{2,}/).map((block) => this.renderBlock(block.trim())).filter(Boolean)
    return blocks.length ? blocks.join("") : "<p></p>"
  }

  renderBlock(block) {
    if (!block) return ""
    if (block.startsWith("```")) return `<pre><code>${block.replace(/^```[a-z]*\n?/i, "").replace(/```$/, "")}</code></pre>`
    if (/^(-{3,}|\*{3,}|_{3,})$/.test(block)) return "<hr>"
    if (/^#\s+/.test(block)) return `<h1>${this.inline(block.replace(/^#\s+/, ""))}</h1>`
    if (/^##\s+/.test(block)) return `<h2>${this.inline(block.replace(/^##\s+/, ""))}</h2>`
    if (/^###\s+/.test(block)) return `<h3>${this.inline(block.replace(/^###\s+/, ""))}</h3>`
    if (/^####\s+/.test(block)) return `<h4>${this.inline(block.replace(/^####\s+/, ""))}</h4>`
    if (block.split("\n").every((line) => /^[-*]\s+/.test(line))) {
      return `<ul>${block.split("\n").map((line) => `<li>${this.inline(line.replace(/^[-*]\s+/, ""))}</li>`).join("")}</ul>`
    }
    if (block.split("\n").every((line) => /^\d+\.\s+/.test(line))) {
      return `<ol>${block.split("\n").map((line) => `<li>${this.inline(line.replace(/^\d+\.\s+/, ""))}</li>`).join("")}</ol>`
    }
    if (block.split("\n").every((line) => /^>\s?/.test(line))) {
      return `<blockquote>${block.split("\n").map((line) => this.inline(line.replace(/^>\s?/, ""))).join("<br>")}</blockquote>`
    }

    return `<p>${this.inline(block).replace(/\n/g, "<br>")}</p>`
  }

  inline(text) {
    return text
      .replace(/`([^`]+)`/g, "<code>$1</code>")
      .replace(/\*\*([^*]+)\*\*/g, "<strong>$1</strong>")
      .replace(/_([^_]+)_/g, "<em>$1</em>")
      .replace(/\[([^\]]+)\]\(([^)]+)\)/g, "<a href=\"$2\">$1</a>")
  }

  escape(value) {
    return value
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#39;")
  }

  sanitizeHtml(html) {
    const template = document.createElement("template")
    template.innerHTML = html
    const allowedTags = new Set([
      "A", "BLOCKQUOTE", "BR", "CODE", "DEL", "EM", "H1", "H2", "H3", "H4", "H5", "H6", "HR", "LI", "OL", "P", "PRE", "STRONG", "TABLE", "TBODY", "TD", "TH", "THEAD", "TR", "UL"
    ])
    const allowedAttributes = new Set(["href", "rel", "target", "title"])

    const clean = (node) => {
      Array.from(node.childNodes).forEach(clean)

      if (node.nodeType !== Node.ELEMENT_NODE) return

      if (!allowedTags.has(node.tagName)) {
        node.replaceWith(...Array.from(node.childNodes))
        return
      }

      Array.from(node.attributes).forEach((attribute) => {
        if (!allowedAttributes.has(attribute.name) || !this.safeAttribute(node, attribute)) {
          node.removeAttribute(attribute.name)
        }
      })

      if (node.tagName === "A" && node.getAttribute("target") === "_blank") {
        node.setAttribute("rel", "noopener noreferrer")
      }
    }

    clean(template.content)
    return template.innerHTML
  }

  safeAttribute(node, attribute) {
    if (attribute.name !== "href") return true

    const value = attribute.value.toString().trim()
    if (value.startsWith("#")) return true

    try {
      return ["http:", "https:", "mailto:"].includes(new URL(value, window.location.origin).protocol)
    } catch {
      return false
    }
  }
}
