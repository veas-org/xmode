import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    const stored = localStorage.getItem("xmode-theme")
    if (stored === "light") document.documentElement.classList.remove("dark")
    if (stored === "dark") document.documentElement.classList.add("dark")
  }

  toggle() {
    document.documentElement.classList.toggle("dark")
    localStorage.setItem("xmode-theme", document.documentElement.classList.contains("dark") ? "dark" : "light")
  }
}
