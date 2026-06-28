import assert from "node:assert/strict"
import { readFile } from "node:fs/promises"
import { test } from "node:test"

const selectorsSource = await readFile(new URL("../../../app/javascript/admin/selectors.js", import.meta.url), "utf8")
const selectionSource = await readFile(new URL("../../../app/javascript/admin/resource_selection.js", import.meta.url), "utf8")
const moduleSource = `${selectorsSource}\n${selectionSource.replace(/^import[\s\S]+?from "\.\/selectors"\n/, "")}`
const moduleUrl = `data:text/javascript;base64,${Buffer.from(moduleSource).toString("base64")}`
const { selectedAdminResourceIds, updateAdminResourceSelectionState } = await import(moduleUrl)

class FakeElement {
  constructor({ checked = false, dataset = {}, value = "" } = {}) {
    this.checked = checked
    this.dataset = dataset
    this.indeterminate = false
    this.value = value
    this.textContent = ""
  }

  querySelector(selector) {
    return this.children?.[selector]
  }
}

const withFakeDocument = (selectorMap, callback) => {
  const originalDocument = globalThis.document
  globalThis.document = {
    querySelectorAll: (selector) => selectorMap[selector] || [],
  }

  try {
    callback()
  } finally {
    globalThis.document = originalDocument
  }
}

test("selectedAdminResourceIds returns checked row ids", () => {
  const checkedRows = [
    new FakeElement({ value: "song-1" }),
    new FakeElement({ value: "song-2" }),
  ]

  withFakeDocument({ "[data-admin-resource-select]:checked": checkedRows }, () => {
    assert.deepEqual(selectedAdminResourceIds(), ["song-1", "song-2"])
  })
})

test("updateAdminResourceSelectionState updates select-all count and required note", () => {
  const rowCheckboxes = [
    new FakeElement({ checked: true, value: "song-1" }),
    new FakeElement({ checked: true, value: "song-2" }),
    new FakeElement({ checked: false, value: "song-3" }),
  ]
  const selectAll = new FakeElement()
  const count = new FakeElement()
  const note = new FakeElement()
  const form = new FakeElement({ dataset: { adminOperationSelectionRequired: "true" } })
  form.children = { "[data-admin-operation-selection-note]": note }
  let afterUpdateCalled = false

  withFakeDocument(
    {
      "[data-admin-resource-select]": rowCheckboxes,
      "[data-admin-resource-select-all]": [selectAll],
      "[data-admin-operation-selection-count]": [count],
      "[data-admin-operation-form]": [form],
    },
    () => {
      updateAdminResourceSelectionState({ afterUpdate: () => { afterUpdateCalled = true } })
    }
  )

  assert.equal(selectAll.checked, false)
  assert.equal(selectAll.indeterminate, true)
  assert.equal(count.textContent, "2")
  assert.equal(note.textContent, "選択した対象で実行できます。")
  assert.equal(afterUpdateCalled, true)
})
