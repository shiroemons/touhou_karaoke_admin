import assert from "node:assert/strict"
import { readFile } from "node:fs/promises"
import { test } from "node:test"

const source = await readFile(new URL("../../../app/javascript/admin/dialog_focus.js", import.meta.url), "utf8")
const moduleUrl = `data:text/javascript;base64,${Buffer.from(source).toString("base64")}`
const { rememberAdminDialogFocus } = await import(moduleUrl)

class FakeDialog {
  constructor() {
    this.eventListeners = {}
  }

  addEventListener(type, callback) {
    this.eventListeners[type] ||= []
    this.eventListeners[type].push(callback)
  }

  close() {
    ;(this.eventListeners.close || []).forEach((callback) => callback())
  }
}

class FakeFocusTarget {
  constructor() {
    this.focused = false
    this.isConnected = true
  }

  focus() {
    this.focused = true
  }
}

test("restores the latest trigger focus when a dialog closes", () => {
  const originalDocument = globalThis.document
  const dialog = new FakeDialog()
  const firstTrigger = new FakeFocusTarget()
  const secondTrigger = new FakeFocusTarget()

  try {
    globalThis.document = { activeElement: firstTrigger }
    rememberAdminDialogFocus(dialog)
    dialog.close()
    assert.equal(firstTrigger.focused, true)

    firstTrigger.focused = false
    globalThis.document.activeElement = secondTrigger
    rememberAdminDialogFocus(dialog)
    dialog.close()
    assert.equal(secondTrigger.focused, true)
    assert.equal(dialog.eventListeners.close.length, 1)
  } finally {
    globalThis.document = originalDocument
  }
})

test("does not focus a disconnected trigger", () => {
  const originalDocument = globalThis.document
  const dialog = new FakeDialog()
  const trigger = new FakeFocusTarget()
  trigger.isConnected = false

  try {
    globalThis.document = { activeElement: trigger }
    rememberAdminDialogFocus(dialog)
    dialog.close()
    assert.equal(trigger.focused, false)
  } finally {
    globalThis.document = originalDocument
  }
})
