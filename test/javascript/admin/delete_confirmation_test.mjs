import assert from "node:assert/strict"
import { readFile } from "node:fs/promises"
import { test } from "node:test"

const source = await readFile(new URL("../../../app/javascript/admin/delete_confirmation.js", import.meta.url), "utf8")
const moduleSource = source.replace(
  /^import \{ adminSelectors \} from "\.\/selectors"\n/,
  `const adminSelectors = {
    deleteConfirmation: "[data-admin-delete-confirmation]",
    deleteConfirmationCancel: "[data-admin-delete-confirmation-cancel]",
    deleteConfirmationConfirm: "[data-admin-delete-confirmation-confirm]",
    deleteConfirmationDialog: "[data-admin-delete-confirmation-dialog]",
    deleteConfirmationMessage: "[data-admin-delete-confirmation-message]",
  }
`
)
const moduleUrl = `data:text/javascript;base64,${Buffer.from(moduleSource).toString("base64")}`
const { setupAdminDeleteConfirmations } = await import(moduleUrl)

class FakeElement {
  constructor({ dataset = {}, connected = true } = {}) {
    this.dataset = dataset
    this.isConnected = connected
    this.eventListeners = {}
    this.queryResults = new Map()
    this.open = false
    this.textContent = ""
    this.focused = false
    this.requestSubmitCalls = 0
  }

  addEventListener(type, callback) {
    this.eventListeners[type] ||= []
    this.eventListeners[type].push(callback)
  }

  click() {
    ;(this.eventListeners.click || []).forEach((callback) => callback({ target: this }))
  }

  close() {
    this.open = false
    ;(this.eventListeners.close || []).forEach((callback) => callback())
  }

  focus() {
    this.focused = true
  }

  querySelector(selector) {
    return this.queryResults.get(selector)
  }

  requestSubmit() {
    this.requestSubmitCalls += 1
    globalThis.document.dispatchSubmit(this)
  }

  showModal() {
    this.open = true
  }

  closest(selector) {
    return selector === "[data-admin-delete-confirmation]" ? this : null
  }
}

const buildFixture = () => {
  const dialog = new FakeElement()
  const message = new FakeElement()
  const cancelButton = new FakeElement()
  const confirmButton = new FakeElement()
  const form = new FakeElement({ dataset: { adminDeleteConfirmation: "サークル「確認対象」を削除します。" } })
  const trigger = new FakeElement()

  dialog.queryResults.set("[data-admin-delete-confirmation-message]", message)
  dialog.queryResults.set("[data-admin-delete-confirmation-confirm]", confirmButton)
  dialog.queryResults.set("[data-admin-delete-confirmation-cancel]", cancelButton)

  const document = {
    activeElement: trigger,
    eventListeners: {},
    querySelector: () => dialog,
    addEventListener(type, callback) {
      this.eventListeners[type] ||= []
      this.eventListeners[type].push(callback)
    },
    dispatchSubmit(target) {
      const event = {
        target,
        defaultPrevented: false,
        propagationStopped: false,
        preventDefault() {
          this.defaultPrevented = true
        },
        stopImmediatePropagation() {
          this.propagationStopped = true
        },
      }
      ;(this.eventListeners.submit || []).forEach((callback) => callback(event))
      this.lastSubmitEvent = event
      return event
    },
  }

  return { cancelButton, confirmButton, dialog, document, form, message, trigger }
}

test("opens the daisyUI dialog, cancels safely, and restores focus", () => {
  const fixture = buildFixture()
  globalThis.document = fixture.document
  setupAdminDeleteConfirmations()

  const event = fixture.document.dispatchSubmit(fixture.form)

  assert.equal(event.defaultPrevented, true)
  assert.equal(event.propagationStopped, true)
  assert.equal(fixture.dialog.open, true)
  assert.equal(fixture.message.textContent, "サークル「確認対象」を削除します。")
  assert.equal(fixture.form.requestSubmitCalls, 0)

  fixture.cancelButton.click()

  assert.equal(fixture.dialog.open, false)
  assert.equal(fixture.form.requestSubmitCalls, 0)
  assert.equal(fixture.trigger.focused, true)
})

test("submits only after confirmation", () => {
  const fixture = buildFixture()
  globalThis.document = fixture.document
  setupAdminDeleteConfirmations()

  fixture.document.dispatchSubmit(fixture.form)
  fixture.confirmButton.click()

  assert.equal(fixture.dialog.open, false)
  assert.equal(fixture.form.requestSubmitCalls, 1)
  assert.equal(fixture.form.dataset.adminDeleteConfirmed, undefined)
  assert.equal(fixture.document.lastSubmitEvent.defaultPrevented, false)
  assert.equal(fixture.document.lastSubmitEvent.propagationStopped, false)
})
