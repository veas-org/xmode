import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    const stored = localStorage.getItem("xmode-theme")
    if (stored === "light" || stored === "dark") this.applyTheme(stored)
    if (stored !== "light" && stored !== "dark") this.syncThemeMeta()
  }

  toggle() {
    const nextTheme = document.documentElement.classList.contains("dark") ? "light" : "dark"
    localStorage.setItem("xmode-theme", nextTheme)
    this.applyTheme(nextTheme)
  }

  applyTheme(theme) {
    document.documentElement.classList.toggle("dark", theme === "dark")
    this.syncThemeMeta()
  }

  syncThemeMeta() {
    const isDark = document.documentElement.classList.contains("dark")
    document.documentElement.dataset.theme = isDark ? "dark" : "light"
    document.documentElement.style.colorScheme = isDark ? "dark" : "light"
    document.querySelector("meta[name='theme-color']")?.setAttribute("content", isDark ? "#07090f" : "#e8f3f9")
  }
}
