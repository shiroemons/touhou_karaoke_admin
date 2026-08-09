import assert from "node:assert/strict"
import { readFile } from "node:fs/promises"
import { test } from "node:test"

class FakeElement {
  constructor({ dataset = {}, textContent = "" } = {}) {
    this.children = []
    this.dataset = dataset
    this.eventListeners = {}
    this.attributes = {}
    this.style = {}
    this.textContent = textContent
  }

  addEventListener(type, callback) {
    this.eventListeners[type] ||= []
    this.eventListeners[type].push(callback)
  }

  appendChild(child) {
    this.children.push(child)
  }

  remove() {
    this.removed = true
  }

  focus(options) {
    this.focused = true
    this.focusOptions = options
  }

  select() {
    this.selected = true
  }

  setAttribute(name, value) {
    this.attributes[name] = value
  }

  async dispatch(type, event = {}) {
    await Promise.all((this.eventListeners[type] || []).map((callback) => callback({ target: this, ...event })))
  }
}

const originalDocument = globalThis.document
const originalNavigator = globalThis.navigator
const originalWindow = globalThis.window
const body = new FakeElement()
const fixture = new FakeElement({ dataset: { adminCopyText: "コピー対象の曲名" } })
const clipboardWrites = []
const timers = []

globalThis.document = {
  body,
  createElement: () => new FakeElement(),
  execCommand: () => true,
  querySelectorAll: (selector) => selector === "[data-admin-copy-text]" ? [fixture] : [],
}
Object.defineProperty(globalThis.navigator, "clipboard", {
  configurable: true,
  value: { writeText: async (text) => clipboardWrites.push(text) },
})
globalThis.window = {
  clearTimeout: () => {},
  setTimeout: (callback) => {
    timers.push(callback)
    return timers.length
  },
}

const source = await readFile(new URL("../../../app/javascript/admin/copy_song_title.js", import.meta.url), "utf8")
const moduleUrl = `data:text/javascript;base64,${Buffer.from(source).toString("base64")}`
const { setupAdminCopyText } = await import(moduleUrl)

test.after(() => {
  globalThis.document = originalDocument
  delete originalNavigator.clipboard
  globalThis.window = originalWindow
})

test("copy controls are keyboard-compatible buttons with accessible status feedback", async () => {
  setupAdminCopyText()
  setupAdminCopyText()

  let prevented = false
  await fixture.dispatch("click", { preventDefault: () => { prevented = true } })

  assert.equal(fixture.eventListeners.click.length, 1)
  assert.equal(prevented, true)
  assert.deepEqual(clipboardWrites, ["コピー対象の曲名"])
  assert.equal(body.children[0].textContent, "コピーしました")
  assert.equal(body.children[0].attributes.role, "status")
  assert.equal(body.children[0].attributes["aria-live"], "polite")
  assert.equal(body.children[0].attributes["aria-atomic"], "true")
  assert.equal(timers.length, 1)
})

test("copy failures expose an assertive error message", async () => {
  globalThis.navigator.clipboard.writeText = async () => {
    throw new Error("clipboard unavailable")
  }
  const errors = []
  const originalConsoleError = console.error
  console.error = (error) => errors.push(error)

  try {
    await fixture.dispatch("click", { preventDefault: () => {} })
  } finally {
    console.error = originalConsoleError
  }

  const toast = body.children[0]
  assert.equal(toast.textContent, "コピーに失敗しました")
  assert.equal(toast.attributes.role, "alert")
  assert.equal(toast.attributes["aria-live"], "assertive")
  assert.equal(errors.length, 1)
})

test("fallback copy restores focus to the copy control", async () => {
  Object.defineProperty(globalThis.navigator, "clipboard", {
    configurable: true,
    value: undefined,
  })

  await fixture.dispatch("click", { preventDefault: () => {} })

  assert.equal(fixture.focused, true)
  assert.deepEqual(fixture.focusOptions, { preventScroll: true })
})
