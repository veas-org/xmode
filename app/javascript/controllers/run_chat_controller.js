import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["stream", "input"]

  connect() {
    this.followStream = true
    if (window.location.hash) {
      this.scrollToHash(window.location.hash)
    } else {
      this.scrollToBottom()
    }
    this.inputTargets.forEach((input) => this.resizeInput(input))
    this.observeStream()
  }

  disconnect() {
    this.streamObserver?.disconnect()
    if (this.hasStreamTarget && this.trackFollowState) {
      this.streamTarget.removeEventListener("scroll", this.trackFollowState)
    }
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

  composerSubmitStart(event) {
    this.followStream = true
    const form = event.currentTarget
    form.querySelectorAll("textarea").forEach((input) => {
      input.readOnly = true
    })
    form.querySelectorAll("button[type='submit'], input[type='submit']").forEach((button) => {
      button.disabled = true
    })
  }

  composerSubmitEnd(event) {
    const form = event.currentTarget
    form.querySelectorAll("textarea").forEach((input) => {
      input.readOnly = false
    })
    form.querySelectorAll("button[type='submit'], input[type='submit']").forEach((button) => {
      button.disabled = false
    })
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

  observeStream() {
    if (!this.hasStreamTarget) return

    this.trackFollowState = () => {
      this.followStream = this.isNearBottom()
    }
    this.streamTarget.addEventListener("scroll", this.trackFollowState)
    this.streamObserver = new MutationObserver(() => {
      if (this.followStream) this.scrollToBottom()
    })
    this.streamObserver.observe(this.streamTarget, { childList: true, subtree: true })
  }

  isNearBottom() {
    if (!this.hasStreamTarget) return true

    const distance = this.streamTarget.scrollHeight - this.streamTarget.scrollTop - this.streamTarget.clientHeight
    return distance < 180
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
