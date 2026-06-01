import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  closeOnEscape(event) {
    if (event.key !== "Escape" || this.element.innerHTML.trim() === "") return

    event.preventDefault()
    event.stopPropagation()
    this.element.replaceChildren()
  }
}
