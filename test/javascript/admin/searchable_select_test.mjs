import assert from "node:assert/strict"
import { readFile } from "node:fs/promises"
import { test } from "node:test"

class FakeClassList {
  add() {}
}

class FakeElement {
  constructor({ checked = false, dataset = {}, hidden = false, textContent = "", value = "" } = {}) {
    this.checked = checked
    this.children = []
    this.classList = new FakeClassList()
    this.dataset = dataset
    this.eventListeners = {}
    this.hidden = hidden
    this.parent = undefined
    this.textContent = textContent
    this.value = value
  }

  addEventListener(type, callback) {
    this.eventListeners[type] ||= []
    this.eventListeners[type].push(callback)
  }

  appendChild(child) {
    child.parent = this
    this.children.push(child)
  }

  blur() {
    this.blurred = true
  }

  closest(selector) {
    return matchesSelector(this, selector) ? this : this.parent?.closest(selector)
  }

  dispatch(type, target = this) {
    ;(this.eventListeners[type] || []).forEach((callback) => callback({ key: "Escape", target }))
  }

  querySelector(selector) {
    return this.querySelectorAll(selector)[0]
  }

  querySelectorAll(selector) {
    return collectDescendants(this).filter((element) => matchesSelector(element, selector))
  }

  replaceChildren() {
    this.children = []
  }
}

const collectDescendants = (element) =>
  element.children.flatMap((child) => [child, ...collectDescendants(child)])

const matchesSelector = (element, selector) => {
  const dataSelector = selector.match(/^\[data-([a-z0-9-]+)\]$/)
  if (!dataSelector) return false

  return dataSelectorToProperty(dataSelector[1]) in element.dataset
}

const dataSelectorToProperty = (name) =>
  name.replace(/-([a-z0-9])/g, (_, character) => character.toUpperCase())

const buildSearchableSelect = () => {
  const container = new FakeElement({ dataset: { adminSearchableSelect: "true" } })
  const search = new FakeElement({ dataset: { adminSearchableSelectSearch: "true" } })
  const chips = new FakeElement({ dataset: { adminSearchableSelectChips: "true" } })
  const status = new FakeElement({ dataset: { adminSearchableSelectStatus: "true" } })
  const values = new FakeElement({
    dataset: {
      adminSearchableSelectValues: "true",
      inputName: "display_artist[circle_ids][]",
    },
  })
  const selectedValue = new FakeElement({
    dataset: { adminSearchableSelectValue: "true" },
    value: "circle-1",
  })
  const options = new FakeElement({ dataset: { adminSearchableSelectOptions: "true" }, hidden: true })
  const firstOption = buildOption("Alpha Circle", "circle-1")
  const secondOption = buildOption("東方LostWord", "circle-2")

  values.appendChild(selectedValue)
  options.appendChild(firstOption.option)
  options.appendChild(secondOption.option)
  ;[search, chips, status, values, options].forEach((child) => container.appendChild(child))

  return {
    checkbox: firstOption.checkbox,
    chips,
    container,
    options,
    search,
    secondCheckbox: secondOption.checkbox,
    status,
    values,
  }
}

const buildOption = (label, value) => {
  const option = new FakeElement({
    dataset: {
      adminSearchableSelectOption: "true",
      searchableText: label,
    },
    textContent: label,
  })
  const checkbox = new FakeElement({
    dataset: { adminSearchableSelectCheckbox: "true" },
    value,
  })
  option.appendChild(checkbox)

  return { checkbox, option }
}

const originalDocument = globalThis.document
const documentEventListeners = {}
globalThis.document = {
  addEventListener: (type, callback) => {
    documentEventListeners[type] ||= []
    documentEventListeners[type].push(callback)
  },
  createElement: () => new FakeElement(),
  querySelectorAll: () => [],
}

const source = await readFile(new URL("../../../app/javascript/admin/searchable_select.js", import.meta.url), "utf8")
const moduleUrl = `data:text/javascript;base64,${Buffer.from(source).toString("base64")}`
const { setupAdminSearchableSelects } = await import(moduleUrl)

test.after(() => {
  globalThis.document = originalDocument
})

test("setupAdminSearchableSelects initializes status chips and checked options", () => {
  const fixture = buildSearchableSelect()
  globalThis.document.querySelectorAll = (selector) => (
    selector === "[data-admin-searchable-select]" ? [fixture.container] : []
  )

  setupAdminSearchableSelects()

  assert.equal(fixture.container.dataset.adminSearchableSelectInitialized, "true")
  assert.equal(fixture.status.textContent, "選択中 1件 / 表示 2件")
  assert.equal(fixture.checkbox.checked, true)
  assert.equal(fixture.values.children.length, 1)
  assert.equal(fixture.chips.children.length, 1)
  assert.equal(fixture.chips.children[0].textContent, "Alpha Circle")
})

test("search input filters visible options and checkbox change writes hidden values", () => {
  const fixture = buildSearchableSelect()
  globalThis.document.querySelectorAll = (selector) => (
    selector === "[data-admin-searchable-select]" ? [fixture.container] : []
  )

  setupAdminSearchableSelects()

  fixture.search.value = "東方"
  fixture.container.dispatch("input", fixture.search)

  assert.equal(fixture.options.hidden, false)
  assert.equal(fixture.status.textContent, "選択中 1件 / 表示 1件")
  assert.equal(fixture.options.children[0].hidden, true)
  assert.equal(fixture.options.children[1].hidden, false)

  fixture.secondCheckbox.checked = true
  fixture.container.dispatch("change", fixture.secondCheckbox)

  assert.equal(fixture.values.children.length, 2)
  assert.deepEqual(fixture.values.children.map((input) => input.value), ["circle-1", "circle-2"])
  assert.equal(fixture.options.hidden, true)
})
