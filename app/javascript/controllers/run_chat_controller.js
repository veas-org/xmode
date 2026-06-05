import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["stream", "input"]

  connect() {
    if (window.location.hash) {
      this.scrollToHash(window.location.hash)
    } else {
      this.scrollToBottom()
    }
    this.inputTargets.forEach((input) => this.resizeInput(input))
  }

  inputTargetConnected(input) {
    this.resizeInput(input)
  }

  autosize(event) {
    this.resizeInput(event.currentTarget)
  }

  submitOnEnter(event) {
    if (event.key !== "Enter" || event.shiftKey || event.metaKey || event.ctrlKey || event.altKey) return

    event.preventDefault()
    const form = event.currentTarget.closest("form")
    if (!form) return

    form.requestSubmit()
  }

  jumpToStep(event) {
    const hash = event.currentTarget.hash
    if (!hash) return

    const target = document.getElementById(hash.slice(1))
    if (!target) return

    event.preventDefault()
    this.selectStepLink(event.currentTarget)
    this.scrollToTarget(target)
    history.replaceState(null, "", hash)
  }

  scrollToBottom() {
    if (!this.hasStreamTarget) return

    requestAnimationFrame(() => {
      this.streamTarget.scrollTop = this.streamTarget.scrollHeight
    })
  }

  scrollToHash(hash) {
    const target = document.getElementById(hash.slice(1))
    if (!target) {
      this.scrollToBottom()
      return
    }

    requestAnimationFrame(() => this.scrollToTarget(target))
  }

  scrollToTarget(target) {
    target.scrollIntoView({ behavior: "smooth", block: "start" })
  }

  resizeInput(input) {
    input.style.height = "auto"
    input.style.height = `${Math.min(input.scrollHeight, 180)}px`
  }

  selectStepLink(selectedLink) {
    this.element.querySelectorAll(".codex-step-outline-link.is-selected").forEach((link) => {
      link.classList.remove("is-selected")
    })
    selectedLink.classList.add("is-selected")
  }
}
