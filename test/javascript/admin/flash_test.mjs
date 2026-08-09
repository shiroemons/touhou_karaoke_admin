import assert from "node:assert/strict"
import { readFile } from "node:fs/promises"
import { test } from "node:test"

const source = await readFile(new URL("../../../app/javascript/admin/flash.js", import.meta.url), "utf8")
const moduleUrl = `data:text/javascript;base64,${Buffer.from(source).toString("base64")}`
const { showAdminFlash } = await import(moduleUrl)

class FakeElement {
  constructor() {
    this.attributes = {}
    this.children = []
    this.dataset = {}
    this.textContent = ""
  }

  appendChild(child) {
    this.children.push(child)
  }

  setAttribute(name, value) {
    this.attributes[name] = value
  }
}

test("showAdminFlash exposes success notifications to assistive technology", () => {
  const originalDocument = globalThis.document
  const container = new FakeElement()
  globalThis.document = {
    createElement: () => new FakeElement(),
    querySelector: () => container,
  }

  try {
    showAdminFlash("更新が完了しました。", "notice", false)

    const [flash] = container.children
    assert.equal(flash.attributes.role, "status")
    assert.equal(flash.attributes["aria-live"], "polite")
    assert.equal(flash.attributes["aria-atomic"], "true")
    assert.equal(flash.textContent, "更新が完了しました。")
  } finally {
    globalThis.document = originalDocument
  }
})

test("showAdminFlash exposes alert notifications assertively", () => {
  const originalDocument = globalThis.document
  const container = new FakeElement()
  globalThis.document = {
    createElement: () => new FakeElement(),
    querySelector: () => container,
  }

  try {
    showAdminFlash("更新に失敗しました。", "alert", false)

    const [flash] = container.children
    assert.equal(flash.attributes.role, "alert")
    assert.equal(flash.attributes["aria-live"], "assertive")
    assert.equal(flash.attributes["aria-atomic"], "true")
    assert.equal(flash.textContent, "更新に失敗しました。")
  } finally {
    globalThis.document = originalDocument
  }
})
