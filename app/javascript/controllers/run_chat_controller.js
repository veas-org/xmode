import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["stream", "input"]

  connect() {
    this.scrollToBottom()
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

  scrollToBottom() {
    if (!this.hasStreamTarget) return

    requestAnimationFrame(() => {
      this.streamTarget.scrollTop = this.streamTarget.scrollHeight
    })
  }

  resizeInput(input) {
    input.style.height = "auto"
    input.style.height = `${Math.min(input.scrollHeight, 180)}px`
  }
}
