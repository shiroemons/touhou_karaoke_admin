import assert from "node:assert/strict"
import { readFile } from "node:fs/promises"
import { test } from "node:test"

class FakeElement {
  constructor({ dataset = {}, value = "" } = {}) {
    this.dataset = dataset
    this.eventListeners = {}
    this.parent = undefined
    this.value = value
    this.dispatchedEvents = []
  }

  addEventListener(type, callback) {
    this.eventListeners[type] ||= []
    this.eventListeners[type].push(callback)
  }

  appendChild(child) {
    child.parent = this
    this.children ||= []
    this.children.push(child)
  }

  closest(selector) {
    return matchesSelector(this, selector) ? this : this.parent?.closest(selector)
  }

  dispatch(type, event = {}) {
    ;(this.eventListeners[type] || []).forEach((callback) => callback({ target: this, ...event }))
  }

  dispatchEvent(event) {
    this.dispatchedEvents.push(event.type)
  }

  querySelector(selector) {
    return collectDescendants(this).find((element) => matchesSelector(element, selector))
  }
}

const collectDescendants = (element) =>
  (element.children || []).flatMap((child) => [child, ...collectDescendants(child)])

const matchesSelector = (element, selector) => {
  const attributeSelectors = [...selector.matchAll(/\[data-([a-z0-9-]+)(?:="([^"]*)")?\]/g)]
  if (attributeSelectors.length === 0) return false

  return attributeSelectors.every(([, attributeName, expected]) => {
    const property = dataSelectorToProperty(attributeName)
    if (!(property in element.dataset)) return false

    return expected === undefined || element.dataset[property] === expected
  })
}

const dataSelectorToProperty = (name) =>
  name.replace(/-([a-z0-9])/g, (_, character) => character.toUpperCase())

const buildTable = () => {
  const table = new FakeElement({ dataset: { adminBulkEditTable: "true" } })

  for (let row = 0; row < 2; row += 1) {
    for (let column = 0; column < 3; column += 1) {
      table.appendChild(new FakeElement({
        dataset: {
          adminBulkCell: "true",
          adminBulkColumnIndex: String(column),
          adminBulkRow: String(row),
        },
      }))
    }
  }

  return table
}

const originalDocument = globalThis.document
const originalEvent = globalThis.Event
const originalSongPickerCalls = []

globalThis.__setOriginalSongPickerText = (element, value) => {
  originalSongPickerCalls.push({ element, value })
}
globalThis.Event = class Event {
  constructor(type) {
    this.type = type
  }
}

const source = await readFile(new URL("../../../app/javascript/admin/bulk_edit_table.js", import.meta.url), "utf8")
const moduleSource = source.replace(
  /^import[\s\S]+?from "\.\/original_song_picker"\n/,
  "const setOriginalSongPickerText = globalThis.__setOriginalSongPickerText\n"
)
const moduleUrl = `data:text/javascript;base64,${Buffer.from(moduleSource).toString("base64")}`
const { setupAdminBulkEditTables } = await import(moduleUrl)

test.after(() => {
  delete globalThis.__setOriginalSongPickerText
  globalThis.document = originalDocument
  globalThis.Event = originalEvent
})

test.beforeEach(() => {
  originalSongPickerCalls.length = 0
})

test("setupAdminBulkEditTables pastes TSV values across cells", () => {
  const table = buildTable()
  globalThis.document = {
    querySelectorAll: (selector) => (
      selector === "[data-admin-bulk-edit-table]" ? [table] : []
    ),
  }

  setupAdminBulkEditTables()

  const startCell = table.querySelector(
    '[data-admin-bulk-cell][data-admin-bulk-row="0"][data-admin-bulk-column-index="1"]'
  )
  let prevented = false
  table.dispatch("paste", {
    clipboardData: { getData: () => "a\tb\nc\td\n" },
    preventDefault: () => { prevented = true },
  })

  assert.equal(table.dataset.adminBulkEditInitialized, "true")
  assert.equal(prevented, false)

  table.dispatch("paste", {
    clipboardData: { getData: () => "a\tb\nc\td\n" },
    preventDefault: () => { prevented = true },
    target: startCell,
  })

  assert.equal(prevented, true)
  assert.equal(table.querySelector('[data-admin-bulk-cell][data-admin-bulk-row="0"][data-admin-bulk-column-index="1"]').value, "a")
  assert.equal(table.querySelector('[data-admin-bulk-cell][data-admin-bulk-row="0"][data-admin-bulk-column-index="2"]').value, "b")
  assert.equal(table.querySelector('[data-admin-bulk-cell][data-admin-bulk-row="1"][data-admin-bulk-column-index="1"]').value, "c")
  assert.equal(table.querySelector('[data-admin-bulk-cell][data-admin-bulk-row="1"][data-admin-bulk-column-index="2"]').value, "d")
  assert.deepEqual(
    table.querySelector('[data-admin-bulk-cell][data-admin-bulk-row="1"][data-admin-bulk-column-index="2"]').dispatchedEvents,
    ["input", "change"]
  )
})

test("setupAdminBulkEditTables delegates original song cells to picker resolver", () => {
  const table = buildTable()
  const originalSongCell = table.querySelector(
    '[data-admin-bulk-cell][data-admin-bulk-row="0"][data-admin-bulk-column-index="0"]'
  )
  originalSongCell.dataset.adminOriginalSongSearch = "true"
  globalThis.document = {
    querySelectorAll: (selector) => (
      selector === "[data-admin-bulk-edit-table]" ? [table] : []
    ),
  }

  setupAdminBulkEditTables()
  table.dispatch("paste", {
    clipboardData: { getData: () => "赤より紅い夢\t表示名" },
    preventDefault: () => {},
    target: originalSongCell,
  })

  assert.equal(originalSongPickerCalls.length, 1)
  assert.equal(originalSongPickerCalls[0].element, originalSongCell)
  assert.equal(originalSongPickerCalls[0].value, "赤より紅い夢")
  assert.equal(table.querySelector('[data-admin-bulk-cell][data-admin-bulk-row="0"][data-admin-bulk-column-index="1"]').value, "表示名")
})
