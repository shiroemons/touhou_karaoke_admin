import assert from "node:assert/strict"
import { readFile } from "node:fs/promises"
import { test } from "node:test"

class FakeElement {
  constructor({ dataset = {} } = {}) {
    this.children = []
    this.dataset = dataset
    this.eventListeners = {}
    this.focused = false
    this.modalOpen = false
    this.showModalCalls = 0
  }

  addEventListener(type, callback) {
    this.eventListeners[type] ||= []
    this.eventListeners[type].push(callback)
  }

  appendChild(child) {
    this.children.push(child)
  }

  close() {
    this.modalOpen = false
    ;(this.eventListeners.close || []).forEach((callback) => callback())
  }

  click() {
    ;(this.eventListeners.click || []).forEach((callback) => callback({ target: this }))
  }

  querySelectorAll(selector) {
    return this.children.filter((element) => matchesSelector(element, selector))
  }

  focus() {
    this.focused = true
  }

  showModal() {
    this.showModalCalls += 1
    this.modalOpen = true
  }

  get open() {
    return this.modalOpen
  }
}

const matchesSelector = (element, selector) => {
  const attributeSelector = selector.match(/^\[data-([a-z0-9-]+)(?:="([^"]*)")?\]$/)
  if (!attributeSelector) return false

  const [, attributeName, expected] = attributeSelector
  const property = dataSelectorToProperty(attributeName)
  if (!(property in element.dataset)) return false

  return expected === undefined || element.dataset[property] === expected
}

const dataSelectorToProperty = (name) =>
  name.replace(/-([a-z0-9])/g, (_, character) => character.toUpperCase())

const originalDocument = globalThis.document
const searchableSelectCalls = []

globalThis.__rememberAdminDialogFocus = (dialog) => {
  const focusTarget = globalThis.document.activeElement
  if (focusTarget?.focus) dialog.addEventListener("close", () => focusTarget.focus())
}

globalThis.__setupAdminSearchableSelects = () => {
  searchableSelectCalls.push("called")
}

const source = await readFile(new URL("../../../app/javascript/admin/association_dialogs.js", import.meta.url), "utf8")
const moduleSource = source
  .replace(
    /^import \{ rememberAdminDialogFocus \} from "\.\/dialog_focus"\n/,
    "const rememberAdminDialogFocus = globalThis.__rememberAdminDialogFocus\n"
  )
  .replace(
    /^import \{ setupAdminSearchableSelects \} from "\.\/searchable_select"\n/m,
    "const setupAdminSearchableSelects = globalThis.__setupAdminSearchableSelects\n"
  )
const moduleUrl = `data:text/javascript;base64,${Buffer.from(moduleSource).toString("base64")}`
const { setupAdminAssociationDialogs } = await import(moduleUrl)

test.after(() => {
  delete globalThis.__rememberAdminDialogFocus
  delete globalThis.__setupAdminSearchableSelects
  globalThis.document = originalDocument
})

test.beforeEach(() => {
  searchableSelectCalls.length = 0
})

test("setupAdminAssociationDialogs opens and closes matching dialog", () => {
  const dialog = new FakeElement({ dataset: { adminAssociationDialog: "artists" } })
  const closeButton = new FakeElement({ dataset: { adminAssociationDialogClose: "true" } })
  const trigger = new FakeElement({ dataset: { adminAssociationDialogTrigger: "artists" } })
  const otherTrigger = new FakeElement({ dataset: { adminAssociationDialogTrigger: "circles" } })
  dialog.appendChild(closeButton)

  globalThis.document = {
    activeElement: trigger,
    querySelectorAll: (selector) => {
      if (selector === "[data-admin-association-dialog]") return [dialog]
      if (selector === '[data-admin-association-dialog-trigger="artists"]') return [trigger]
      if (selector === '[data-admin-association-dialog-trigger="circles"]') return [otherTrigger]

      return []
    },
  }

  setupAdminAssociationDialogs()
  otherTrigger.click()

  assert.equal(dialog.dataset.adminAssociationDialogInitialized, "true")
  assert.equal(dialog.modalOpen, false)
  assert.equal(searchableSelectCalls.length, 0)

  trigger.click()

  assert.equal(dialog.modalOpen, true)
  assert.equal(searchableSelectCalls.length, 1)

  trigger.click()

  assert.equal(dialog.showModalCalls, 1)
  assert.equal(searchableSelectCalls.length, 1)

  closeButton.click()

  assert.equal(dialog.modalOpen, false)
  assert.equal(trigger.focused, true)
})

test("setupAdminAssociationDialogs does not attach duplicate listeners", () => {
  const dialog = new FakeElement({ dataset: { adminAssociationDialog: "artists" } })
  const trigger = new FakeElement({ dataset: { adminAssociationDialogTrigger: "artists" } })
  globalThis.document = {
    querySelectorAll: (selector) => {
      if (selector === "[data-admin-association-dialog]") return [dialog]
      if (selector === '[data-admin-association-dialog-trigger="artists"]') return [trigger]

      return []
    },
  }

  setupAdminAssociationDialogs()
  setupAdminAssociationDialogs()
  trigger.click()

  assert.equal(searchableSelectCalls.length, 1)
})
