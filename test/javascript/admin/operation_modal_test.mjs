import assert from "node:assert/strict"
import { readFile } from "node:fs/promises"
import { test } from "node:test"

const source = await readFile(new URL("../../../app/javascript/admin/operation_modal.js", import.meta.url), "utf8")
globalThis.__rememberAdminDialogFocus = (dialog) => {
  const focusTarget = globalThis.document.activeElement
  if (focusTarget?.focus) dialog.addEventListener("close", () => focusTarget.focus())
}
const moduleSource = source
  .replace(
    /^import \{ rememberAdminDialogFocus \} from "\.\/dialog_focus"\n/,
    "const rememberAdminDialogFocus = globalThis.__rememberAdminDialogFocus\n"
  )
  .replace(
    /^import \{ adminSelectors \} from "\.\/selectors"\n/m,
    `const adminSelectors = {
  operationModal: "[data-admin-operation-modal]",
  operationModalClose: "[data-admin-operation-modal-close]",
  operationModalTitle: "[data-admin-operation-modal-title]",
  operationPanel: "[data-admin-operation-panel]",
  operationTrigger: "[data-admin-operation-trigger]",
}
`
  )
const moduleUrl = `data:text/javascript;base64,${Buffer.from(moduleSource).toString("base64")}`
const { setupAdminOperationModal } = await import(moduleUrl)

class FakeElement {
  constructor({ dataset = {}, textContent = "" } = {}) {
    this.dataset = dataset
    this.textContent = textContent
    this.children = []
    this.eventListeners = {}
    this.queryResults = new Map()
    this.hidden = false
    this.modalOpen = false
    this.showModalCalls = 0
    this.focused = false
  }

  addEventListener(type, callback) {
    this.eventListeners[type] ||= []
    this.eventListeners[type].push(callback)
  }

  click() {
    const event = {
      target: this,
      defaultPrevented: false,
      preventDefault() {
        this.defaultPrevented = true
      },
    }
    ;(this.eventListeners.click || []).forEach((callback) => callback(event))
    return event
  }

  close() {
    this.modalOpen = false
    ;(this.eventListeners.close || []).forEach((callback) => callback())
  }

  dispatchEvent() {}

  focus() {
    this.focused = true
  }

  querySelector(selector) {
    return this.queryResults.get(selector) || null
  }

  querySelectorAll(selector) {
    return selector === "[data-admin-operation-panel]" ? this.children : []
  }

  showModal() {
    this.showModalCalls += 1
    this.modalOpen = true
  }

  get open() {
    return this.modalOpen
  }

  closest() {
    return null
  }
}

test("operation modal restores focus to the trigger after closing", () => {
  const originalDocument = globalThis.document
  const originalEvent = globalThis.Event
  const modal = new FakeElement({ dataset: { adminOperationModal: "true", adminOperationResource: "song" } })
  const title = new FakeElement()
  const closeButton = new FakeElement()
  const panel = new FakeElement({ dataset: { adminOperationPanel: "export_songs" } })
  const details = {
    open: true,
    removeAttribute(name) {
      if (name === "open") this.open = false
    },
    setAttribute(name) {
      if (name === "open") this.open = true
    },
  }
  const trigger = new FakeElement({
    dataset: {
      adminOperationTrigger: "true",
      adminOperationResource: "song",
      adminOperationKey: "export_songs",
      adminOperationLabel: "楽曲をエクスポート",
    },
    textContent: "楽曲をエクスポート",
  })
  trigger.closest = () => details
  modal.children = [panel]
  modal.queryResults.set("[data-admin-operation-modal-title]", title)
  modal.queryResults.set("[data-admin-operation-modal-close]", closeButton)
  globalThis.Event = class FakeEvent {
    constructor(type) {
      this.type = type
    }
  }
  globalThis.document = {
    activeElement: trigger,
    querySelectorAll(selector) {
      if (selector === "[data-admin-operation-modal]") return [modal]
      if (selector === "[data-admin-operation-trigger]") return [trigger]

      return []
    },
  }

  try {
    setupAdminOperationModal()
    const event = trigger.click()

    assert.equal(event.defaultPrevented, true)
    assert.equal(modal.modalOpen, true)
    assert.equal(modal.showModalCalls, 1)
    assert.equal(panel.hidden, false)
    assert.equal(details.open, false)

    const duplicateEvent = trigger.click()

    assert.equal(duplicateEvent.defaultPrevented, true)
    assert.equal(modal.showModalCalls, 1)

    modal.close()

    assert.equal(trigger.focused, true)
    assert.equal(details.open, true)
  } finally {
    globalThis.document = originalDocument
    globalThis.Event = originalEvent
    delete globalThis.__rememberAdminDialogFocus
  }
})
