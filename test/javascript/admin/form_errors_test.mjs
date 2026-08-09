import assert from "node:assert/strict"
import { readFile } from "node:fs/promises"
import { test } from "node:test"

const source = await readFile(new URL("../../../app/javascript/admin/form_errors.js", import.meta.url), "utf8")
const moduleUrl = `data:text/javascript;base64,${Buffer.from(source).toString("base64")}`
const { focusAdminFormErrorSummary, setupAdminFormErrors } = await import(moduleUrl)

class FakeElement {
  constructor() {
    this.focused = false
  }

  focus() {
    this.focused = true
  }
}

const createDocument = (summary) => ({
  documentElement: { dataset: {} },
  querySelector: () => summary,
})

test("focusAdminFormErrorSummary focuses the error summary when present", () => {
  const summary = new FakeElement()

  assert.equal(focusAdminFormErrorSummary(createDocument(summary)), true)
  assert.equal(summary.focused, true)
})

test("focusAdminFormErrorSummary does nothing when no summary is present", () => {
  assert.equal(focusAdminFormErrorSummary(createDocument(null)), false)
})

test("setupAdminFormErrors focuses the summary only once", () => {
  const originalDocument = globalThis.document
  const summary = new FakeElement()
  const fakeDocument = createDocument(summary)
  let focusCount = 0
  summary.focus = () => {
    focusCount += 1
  }
  globalThis.document = fakeDocument

  try {
    setupAdminFormErrors()
    setupAdminFormErrors()

    assert.equal(focusCount, 1)
    assert.equal(fakeDocument.documentElement.dataset.adminFormErrorsInitialized, "true")
  } finally {
    globalThis.document = originalDocument
  }
})
