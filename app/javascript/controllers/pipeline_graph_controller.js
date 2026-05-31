import { Controller } from "@hotwired/stimulus"
import "rete"

export default class extends Controller {
  static targets = ["graph", "field"]
  static values = { actions: Array }

  connect() {
    this.graph = this.safeGraph()
    this.render()
  }

  addNode(event) {
    const action = this.actionsValue.find((candidate) => candidate.key === event.currentTarget.dataset.actionKey)
    if (!action) return

    const id = `node-${Date.now()}`
    const previous = this.graph.nodes[this.graph.nodes.length - 1]
    this.graph.nodes.push({ id, action_key: action.key, action_id: action.id, label: action.name, x: 80 + this.graph.nodes.length * 180, y: 160 })
    if (previous) {
      this.graph.edges.push({ id: `${previous.id}-${id}`, from: previous.id, to: id, condition: "success" })
    }
    this.persist()
    this.render()
  }

  clear() {
    this.graph = { nodes: [], edges: [] }
    this.persist()
    this.render()
  }

  safeGraph() {
    try {
      return JSON.parse(this.fieldTarget.value || "{\"nodes\":[],\"edges\":[]}")
    } catch (_error) {
      return { nodes: [], edges: [] }
    }
  }

  persist() {
    this.fieldTarget.value = JSON.stringify(this.graph, null, 2)
  }

  render() {
    const svgEdges = this.graph.edges.map((edge) => {
      const from = this.graph.nodes.find((node) => node.id === edge.from)
      const to = this.graph.nodes.find((node) => node.id === edge.to)
      if (!from || !to) return ""
      return `<line x1="${from.x + 130}" y1="${from.y + 24}" x2="${to.x}" y2="${to.y + 24}" stroke="rgba(56,189,248,.55)" stroke-width="2"/><text x="${(from.x + to.x) / 2 + 55}" y="${from.y + 16}" fill="rgb(161,161,170)" font-size="11">${edge.condition || "success"}</text>`
    }).join("")

    const nodes = this.graph.nodes.map((node) => (
      `<div class="absolute w-36 rounded-md border border-sky-300/25 bg-zinc-950 px-3 py-2 text-sm shadow-xl" style="left:${node.x}px; top:${node.y}px">
        <p class="font-medium text-white">${node.label}</p>
        <p class="mt-1 text-xs text-zinc-500">${node.action_key}</p>
      </div>`
    )).join("")

    this.graphTarget.innerHTML = `<svg class="absolute inset-0 h-full w-full">${svgEdges}</svg>${nodes}`
  }
}
