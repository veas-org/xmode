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
    const reference = event.currentTarget.dataset.actionReference
    const action = this.actionsValue.find((candidate) => candidate.reference === reference)
    if (!action) return

    const id = `node-${Date.now()}`
    this.appendNode({ id, type: "action", action_key: action.key, action_version: action.version, action_id: action.id, label: action.name, x: this.nextX(), y: 160 }, "success")
  }

  addInteractionNode(event) {
    const type = event.currentTarget.dataset.nodeType
    const id = `${type}-${Date.now()}`
    const node = this.interactionNodeFor(type, id)
    if (!node) return

    this.appendNode(node, "answered")
  }

  appendNode(node, condition) {
    const previous = this.graph.nodes[this.graph.nodes.length - 1]
    this.graph.nodes.push(node)
    if (previous) {
      this.graph.edges.push({ id: `${previous.id}-${node.id}`, from: previous.id, to: node.id, condition })
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

  nextX() {
    return 80 + this.graph.nodes.length * 180
  }

  interactionNodeFor(type, id) {
    const base = { id, type, x: this.nextX(), y: type === "follow_up" ? 260 : 160 }
    if (type === "decision") {
      return {
        ...base,
        label: "Decision",
        question: "Choose how this pipeline should continue.",
        choices: [
          { key: "continue", label: "Continue", next: null },
          { key: "stop", label: "Stop run", action: "reject" }
        ]
      }
    }
    if (type === "follow_up") {
      return {
        ...base,
        label: "Follow-up",
        prompt: "Add the missing context before this pipeline continues."
      }
    }
    if (type === "goal_check") {
      return {
        ...base,
        label: "Goal Check",
        question: "Confirm the run goal before continuing.",
        checks: [ "Objective is clear", "Plan is reviewable", "Evidence path is defined" ],
        choices: [
          { key: "approve", label: "Goal is clear", next: null },
          { key: "revise", label: "Revise context", next: null }
        ]
      }
    }
  }

  render() {
    const svgEdges = this.graph.edges.map((edge) => {
      const from = this.graph.nodes.find((node) => node.id === edge.from)
      const to = this.graph.nodes.find((node) => node.id === edge.to)
      if (!from || !to) return ""
      return `<line x1="${from.x + 130}" y1="${from.y + 24}" x2="${to.x}" y2="${to.y + 24}" stroke="rgba(56,189,248,.55)" stroke-width="2"/><text x="${(from.x + to.x) / 2 + 55}" y="${from.y + 16}" fill="rgb(161,161,170)" font-size="11">${edge.condition || "success"}</text>`
    }).join("")

    const nodes = this.graph.nodes.map((node) => {
      const type = node.type || "action"
      const subtitle = type === "action" ? [node.action_key, node.action_version ? `@${node.action_version}` : null].filter(Boolean).join(" ") : type.replace("_", " ")
      const border = type === "action" ? "border-sky-300/25" : "border-emerald-300/25"
      return (
      `<div class="absolute w-40 rounded-md border ${border} bg-zinc-950 px-3 py-2 text-sm shadow-xl" style="left:${node.x}px; top:${node.y}px">
        <p class="truncate font-medium text-white">${node.label || type}</p>
        <p class="mt-1 truncate text-xs text-zinc-500">${subtitle}</p>
      </div>`
      )
    }).join("")

    this.graphTarget.innerHTML = `<svg class="absolute inset-0 h-full w-full">${svgEdges}</svg>${nodes}`
  }
}
