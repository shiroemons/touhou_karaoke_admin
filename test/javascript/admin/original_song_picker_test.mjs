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
    return Promise.all((this.eventListeners[type] || []).map((callback) => callback({ target: this, ...event })))
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
  const status = new FakeElement({ dataset: { adminOriginalSongPickerStatus: "true" } })
  const options = new FakeElement({ dataset: { adminOriginalSongOptions: "true" }, hidden: true })

  ;[valueInput, chips, search, status, options].forEach((child) => picker.appendChild(child))

  return { chips, options, picker, search, status, valueInput }
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

test("setOriginalSongPickerText appends to existing selection when append is true", async () => {
  const fixture = buildPicker({ initialValue: "既存曲" })
  globalThis.document.querySelectorAll = (selector) => (
    selector === "[data-admin-original-song-picker]" ? [fixture.picker] : []
  )
  setupAdminOriginalSongPickers()

  globalThis.fetch = async () => ({
    ok: true,
    json: async () => ({
      items: [
        { exists: true, title: "新しい曲" },
      ],
    }),
  })

  await setOriginalSongPickerText(fixture.search, "新しい曲", { append: true })

  assert.equal(fixture.search.value, "")
  assert.equal(fixture.valueInput.value, "既存曲/新しい曲")
  assert.deepEqual(fixture.chips.children.map((chip) => chip.textContent), ["既存曲", "新しい曲"])
  assert.deepEqual(fixture.chips.children.map((chip) => chip.dataset.adminOriginalSongStatus), ["valid", "valid"])
})

test("normal multiline paste appends all original songs to the focused picker", async () => {
  const fixture = buildPicker({ initialValue: "既存曲" })
  globalThis.document.querySelectorAll = (selector) => (
    selector === "[data-admin-original-song-picker]" ? [fixture.picker] : []
  )
  setupAdminOriginalSongPickers()
  globalThis.fetch = async (_url, options) => {
    assert.equal(JSON.parse(options.body).text, "新しい曲\n別の曲")
    return {
      ok: true,
      json: async () => ({
        items: [
          { exists: true, title: "新しい曲" },
          { exists: true, title: "別の曲" },
        ],
      }),
    }
  }

  let prevented = false
  let stopped = false
  await fixture.search.dispatch("paste", {
    clipboardData: { getData: () => "新しい曲\n別の曲\n" },
    preventDefault: () => { prevented = true },
    stopPropagation: () => { stopped = true },
  })

  assert.equal(prevented, true)
  assert.equal(stopped, true)
  assert.equal(fixture.valueInput.value, "既存曲/新しい曲/別の曲")
  assert.deepEqual(fixture.chips.children.map((chip) => chip.textContent), ["既存曲", "新しい曲", "別の曲"])
})

test("shift multiline paste is left for the bulk table handler", async () => {
  const fixture = buildPicker()
  globalThis.document.querySelectorAll = (selector) => (
    selector === "[data-admin-original-song-picker]" ? [fixture.picker] : []
  )
  setupAdminOriginalSongPickers()
  let fetchCalls = 0
  globalThis.fetch = async () => {
    fetchCalls += 1
    return { ok: true, json: async () => ({ items: [] }) }
  }

  let prevented = false
  let stopped = false
  await fixture.search.dispatch("paste", {
    clipboardData: { getData: () => "1曲目\n2曲目" },
    shiftKey: true,
    preventDefault: () => { prevented = true },
    stopPropagation: () => { stopped = true },
  })

  assert.equal(prevented, false)
  assert.equal(stopped, false)
  assert.equal(fetchCalls, 0)
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

test("original song search exposes an actionable error when options cannot be loaded", async () => {
  const fixture = buildPicker()
  globalThis.document.querySelectorAll = (selector) => (
    selector === "[data-admin-original-song-picker]" ? [fixture.picker] : []
  )
  setupAdminOriginalSongPickers()
  globalThis.fetch = async () => ({ ok: false, status: 503 })

  fixture.search.value = "検索対象"
  await fixture.search.dispatch("input")

  assert.match(fixture.status.textContent, /候補の取得に失敗しました/)
  assert.equal(fixture.status.dataset.adminOriginalSongStatusLevel, "error")
  assert.equal(fixture.search.value, "検索対象")
  assert.equal(fixture.options.hidden, true)
})

test("original song search explains when no candidates match", async () => {
  const fixture = buildPicker()
  globalThis.document.querySelectorAll = (selector) => (
    selector === "[data-admin-original-song-picker]" ? [fixture.picker] : []
  )
  setupAdminOriginalSongPickers()
  globalThis.fetch = async () => ({ ok: true, json: async () => [] })

  fixture.search.value = "一致しない原曲"
  await fixture.search.dispatch("input")

  assert.equal(fixture.status.textContent, "一致する原曲がありません。")
  assert.equal(fixture.status.dataset.adminOriginalSongStatusLevel, undefined)
  assert.equal(fixture.options.hidden, true)
})

test("original song search treats malformed option data as a retryable error", async () => {
  const fixture = buildPicker()
  globalThis.document.querySelectorAll = (selector) => (
    selector === "[data-admin-original-song-picker]" ? [fixture.picker] : []
  )
  setupAdminOriginalSongPickers()
  globalThis.fetch = async () => ({ ok: true, json: async () => ({ items: [] }) })

  fixture.search.value = "不正な候補データ"
  await fixture.search.dispatch("input")

  assert.match(fixture.status.textContent, /候補の取得に失敗しました/)
  assert.equal(fixture.status.dataset.adminOriginalSongStatusLevel, "error")
  assert.equal(fixture.options.hidden, true)
})

test("original song search ignores a stale response after a newer query", async () => {
  const fixture = buildPicker()
  globalThis.document.querySelectorAll = (selector) => (
    selector === "[data-admin-original-song-picker]" ? [fixture.picker] : []
  )
  setupAdminOriginalSongPickers()
  const requests = []
  globalThis.fetch = (url, options) => new Promise((resolve) => {
    requests.push({ options, resolve, url })
  })

  fixture.search.value = "古い検索"
  const firstRequest = fixture.search.dispatch("input")
  fixture.search.value = "新しい検索"
  const secondRequest = fixture.search.dispatch("input")

  requests[1].resolve({
    ok: true,
    json: async () => [{ label: "新しい候補", title: "新しい候補" }],
  })
  await secondRequest

  requests[0].resolve({
    ok: true,
    json: async () => [{ label: "古い候補", title: "古い候補" }],
  })
  await firstRequest

  assert.equal(fixture.options.children[0].textContent, "新しい候補")
  assert.match(fixture.status.textContent, /1件の候補があります/)
})
