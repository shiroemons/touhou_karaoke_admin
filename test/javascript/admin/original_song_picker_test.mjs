import assert from "node:assert/strict"
import { readFile } from "node:fs/promises"
import { test } from "node:test"

class FakeClassList {
  add() {}
}

class FakeElement {
  constructor({ dataset = {}, hidden = false, rect = {}, textContent = "", value = "" } = {}) {
    this.children = []
    this.classList = new FakeClassList()
    this.dataset = dataset
    this.eventListeners = {}
    this.hidden = hidden
    this.parent = undefined
    this.rect = { bottom: 40, left: 8, top: 10, width: 180, ...rect }
    this.style = {}
    this.textContent = textContent
    this.title = ""
    this.type = undefined
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

  closest(selector) {
    return matchesSelector(this, selector) ? this : this.parent?.closest(selector)
  }

  dispatch(type, event = {}) {
    ;(this.eventListeners[type] || []).forEach((callback) => callback({ target: this, ...event }))
  }

  dispatchEvent(event) {
    this.dispatchedEvents ||= []
    this.dispatchedEvents.push(event.type)
  }

  focus() {
    this.focused = true
  }

  getBoundingClientRect() {
    return this.rect
  }

  querySelector(selector) {
    return this.querySelectorAll(selector)[0]
  }

  querySelectorAll(selector) {
    return collectDescendants(this).filter((element) => matchesSelector(element, selector))
  }

  set innerHTML(value) {
    this.children = []
    this._innerHTML = value
  }

  get innerHTML() {
    return this._innerHTML || ""
  }
}

const collectDescendants = (element) =>
  element.children.flatMap((child) => [child, ...collectDescendants(child)])

const matchesSelector = (element, selector) => {
  const dataSelector = selector.match(/^\[data-([a-z0-9-]+)\]$/)
  if (dataSelector) return dataSelectorToProperty(dataSelector[1]) in element.dataset

  const attributeSelector = selector.match(/^meta\[name='csrf-token'\]$/)
  if (attributeSelector) return element.tagName === "META" && element.name === "csrf-token"

  return false
}

const dataSelectorToProperty = (name) =>
  name.replace(/-([a-z0-9])/g, (_, character) => character.toUpperCase())

const buildPicker = ({ initialValue = "" } = {}) => {
  const picker = new FakeElement({
    dataset: {
      adminOriginalSongPicker: "true",
      optionsUrl: "/options",
      resolveUrl: "/resolve",
    },
  })
  const valueInput = new FakeElement({ dataset: { adminOriginalSongValue: "true" }, value: initialValue })
  const chips = new FakeElement({ dataset: { adminOriginalSongChips: "true" } })
  const search = new FakeElement({ dataset: { adminOriginalSongSearch: "true" } })
  const options = new FakeElement({ dataset: { adminOriginalSongOptions: "true" }, hidden: true })

  ;[valueInput, chips, search, options].forEach((child) => picker.appendChild(child))

  return { chips, options, picker, search, valueInput }
}

const originalDocument = globalThis.document
const originalFetch = globalThis.fetch
const originalWindow = globalThis.window
const documentEventListeners = {}
const createdElements = []

globalThis.document = {
  addEventListener: (type, callback) => {
    documentEventListeners[type] ||= []
    documentEventListeners[type].push(callback)
  },
  createElement: () => {
    const element = new FakeElement()
    createdElements.push(element)
    return element
  },
  querySelector: () => ({ content: "csrf-token" }),
  querySelectorAll: () => [],
}
globalThis.window = {
  addEventListener: (type, callback) => {
    documentEventListeners[`window:${type}`] ||= []
    documentEventListeners[`window:${type}`].push(callback)
  },
  innerHeight: 812,
  innerWidth: 375,
  location: { origin: "http://example.test" },
}
globalThis.Event = class Event {
  constructor(type) {
    this.type = type
  }
}

const source = await readFile(new URL("../../../app/javascript/admin/original_song_picker.js", import.meta.url), "utf8")
const moduleUrl = `data:text/javascript;base64,${Buffer.from(source).toString("base64")}`
const { setOriginalSongPickerText, setupAdminOriginalSongPickers } = await import(moduleUrl)

test.after(() => {
  globalThis.document = originalDocument
  globalThis.fetch = originalFetch
  globalThis.window = originalWindow
})

test("setupAdminOriginalSongPickers initializes chips from hidden value", () => {
  const fixture = buildPicker({ initialValue: "赤より紅い夢/紅楼" })
  globalThis.document.querySelectorAll = (selector) => (
    selector === "[data-admin-original-song-picker]" ? [fixture.picker] : []
  )

  setupAdminOriginalSongPickers()

  assert.equal(fixture.picker.dataset.adminOriginalSongPickerInitialized, "true")
  assert.equal(fixture.valueInput.value, "赤より紅い夢/紅楼")
  assert.deepEqual(fixture.chips.children.map((chip) => chip.textContent), ["赤より紅い夢", "紅楼"])
  assert.deepEqual(fixture.chips.children.map((chip) => chip.dataset.adminOriginalSongStatus), ["valid", "valid"])
})

test("setOriginalSongPickerText resolves selected items and renders candidates for invalid items", async () => {
  const fixture = buildPicker()
  globalThis.fetch = async () => ({
    ok: true,
    json: async () => ({
      items: [
        { exists: true, title: "赤より紅い夢" },
        {
          candidates: [
            { label: "[東方紅魔郷] 紅楼", title: "紅楼" },
          ],
          exists: false,
          title: "紅楼?",
        },
      ],
    }),
  })

  await setOriginalSongPickerText(fixture.search, "赤より紅い夢/紅楼?")

  assert.equal(fixture.search.value, "")
  assert.equal(fixture.valueInput.value, "赤より紅い夢/紅楼?")
  assert.deepEqual(fixture.chips.children.map((chip) => chip.dataset.adminOriginalSongStatus), ["valid", "invalid"])
  assert.equal(fixture.options.hidden, false)
  assert.equal(fixture.options.children.length, 1)
  assert.equal(fixture.options.children[0].dataset.adminOriginalSongSelect, "紅楼")
  assert.equal(fixture.options.children[0].dataset.adminOriginalSongCandidateFor, "紅楼?")
})

test("setOriginalSongPickerText marks text invalid when resolve fails", async () => {
  const fixture = buildPicker()
  const errors = []
  const originalConsoleError = console.error
  console.error = (error) => errors.push(error)
  globalThis.fetch = async () => ({ ok: false, status: 500 })

  try {
    await setOriginalSongPickerText(fixture.search, "存在しない原曲")
  } finally {
    console.error = originalConsoleError
  }

  assert.equal(fixture.search.value, "")
  assert.equal(fixture.valueInput.value, "存在しない原曲")
  assert.equal(fixture.chips.children.length, 1)
  assert.equal(fixture.chips.children[0].dataset.adminOriginalSongStatus, "invalid")
  assert.equal(fixture.options.hidden, true)
  assert.equal(errors.length, 1)
})
