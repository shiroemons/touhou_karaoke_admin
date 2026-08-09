import assert from "node:assert/strict"
import { readFile } from "node:fs/promises"
import { test } from "node:test"

const source = await readFile(new URL("../../../app/javascript/admin/infinite_scroll.js", import.meta.url), "utf8")
const moduleUrl = `data:text/javascript;base64,${Buffer.from(source).toString("base64")}`
const { setupAdminInfiniteScroll } = await import(moduleUrl)

class FakeElement {
  constructor({ attributes = {}, dataset = {}, hidden = false } = {}) {
    this.attributes = attributes
    this.dataset = dataset
    this.hidden = hidden
    this.textContent = ""
    this.eventListeners = {}
    this.insertedHtml = []
    this.rows = []
  }

  addEventListener(type, callback) {
    this.eventListeners[type] ||= []
    this.eventListeners[type].push(callback)
  }

  click() {
    this.eventListeners.click?.forEach((callback) => callback({ target: this }))
  }

  closest() {
    return {}
  }

  insertAdjacentHTML(_position, html) {
    this.insertedHtml.push(html)
    this.rows.push(html)
  }

  querySelector(selector) {
    return this.children?.[selector] || null
  }

  querySelectorAll() {
    return this.rows
  }

  setAttribute(name, value) {
    this.attributes[name] = value
  }
}

const buildFixture = () => {
  const sentinel = new FakeElement({ dataset: { nextUrl: "/next" } })
  const status = new FakeElement()
  const retryButton = new FakeElement({ hidden: true })
  sentinel.children = {
    "[data-admin-infinite-scroll-status]": status,
    "[data-admin-infinite-scroll-retry]": retryButton,
  }
  const rows = new FakeElement()
  let observer
  const document = {
    querySelector(selector) {
      return {
        "[data-admin-infinite-scroll]": sentinel,
        "#admin-resource-rows": rows,
      }[selector] || null
    },
  }

  globalThis.IntersectionObserver = class {
    constructor(callback) {
      this.callback = callback
      this.disconnected = false
      observer = this
    }

    observe() {}

    disconnect() {
      this.disconnected = true
    }
  }

  return { document, observer: () => observer, retryButton, rows, sentinel, status }
}

const waitForAsyncWork = () => new Promise((resolve) => setImmediate(resolve))

test("infinite scroll exposes a retry action after a failed request", async () => {
  const originalDocument = globalThis.document
  const originalFetch = globalThis.fetch
  let calls = 0
  const fixture = buildFixture()

  globalThis.document = fixture.document
  globalThis.fetch = async () => {
    calls += 1
    if (calls === 1) throw new Error("network error")

    return {
      ok: true,
      json: async () => ({ html: "<tr></tr>", next_url: null }),
    }
  }

  try {
    setupAdminInfiniteScroll()
    fixture.observer().callback([{ isIntersecting: true }])
    await waitForAsyncWork()

    assert.equal(calls, 1)
    assert.equal(fixture.status.textContent, "読み込みに失敗しました。再試行してください。")
    assert.equal(fixture.retryButton.hidden, false)
    assert.equal(fixture.sentinel.attributes["aria-busy"], "false")

    fixture.retryButton.click()
    await waitForAsyncWork()

    assert.equal(calls, 2)
    assert.deepEqual(fixture.rows.insertedHtml, ["<tr></tr>"])
    assert.equal(fixture.retryButton.hidden, true)
    assert.equal(fixture.sentinel.hidden, true)
    assert.equal(fixture.status.textContent, "すべて読み込みました")
    assert.equal(fixture.sentinel.attributes["aria-busy"], "false")
  } finally {
    globalThis.document = originalDocument
    globalThis.fetch = originalFetch
    delete globalThis.IntersectionObserver
  }
})

test("infinite scroll ignores duplicate observer events during a request", async () => {
  const originalDocument = globalThis.document
  const originalFetch = globalThis.fetch
  let calls = 0
  let resolveFetch
  const fixture = buildFixture()

  globalThis.document = fixture.document
  globalThis.fetch = () => {
    calls += 1
    return new Promise((resolve) => {
      resolveFetch = resolve
    })
  }

  try {
    setupAdminInfiniteScroll()
    fixture.observer().callback([{ isIntersecting: true }])
    fixture.observer().callback([{ isIntersecting: true }])

    assert.equal(calls, 1)
    resolveFetch({ ok: true, json: async () => ({ html: "<tr></tr>", next_url: "/admin/last" }) })
    await waitForAsyncWork()
    assert.equal(calls, 1)
    assert.equal(fixture.sentinel.dataset.nextUrl, "/admin/last")
    assert.equal(fixture.sentinel.attributes["aria-busy"], "false")
  } finally {
    globalThis.document = originalDocument
    globalThis.fetch = originalFetch
    delete globalThis.IntersectionObserver
  }
})

test("infinite scroll rejects malformed payloads without changing the rows", async () => {
  const originalDocument = globalThis.document
  const originalFetch = globalThis.fetch
  const fixture = buildFixture()

  globalThis.document = fixture.document
  globalThis.fetch = async () => ({
    ok: true,
    json: async () => ({ html: 42, next_url: null }),
  })

  try {
    setupAdminInfiniteScroll()
    fixture.observer().callback([{ isIntersecting: true }])
    await waitForAsyncWork()

    assert.deepEqual(fixture.rows.insertedHtml, [])
    assert.equal(fixture.sentinel.dataset.nextUrl, "/next")
    assert.equal(fixture.retryButton.hidden, false)
    assert.equal(fixture.status.textContent, "読み込みに失敗しました。再試行してください。")
    assert.equal(fixture.sentinel.attributes["aria-busy"], "false")
  } finally {
    globalThis.document = originalDocument
    globalThis.fetch = originalFetch
    delete globalThis.IntersectionObserver
  }
})

test("infinite scroll rejects a non-advancing next URL", async () => {
  const originalDocument = globalThis.document
  const originalFetch = globalThis.fetch
  const fixture = buildFixture()

  globalThis.document = fixture.document
  globalThis.fetch = async () => ({
    ok: true,
    json: async () => ({ html: "<tr></tr>", next_url: "/next" }),
  })

  try {
    setupAdminInfiniteScroll()
    fixture.observer().callback([{ isIntersecting: true }])
    await waitForAsyncWork()

    assert.deepEqual(fixture.rows.insertedHtml, [])
    assert.equal(fixture.sentinel.dataset.nextUrl, "/next")
    assert.equal(fixture.retryButton.hidden, false)
  } finally {
    globalThis.document = originalDocument
    globalThis.fetch = originalFetch
    delete globalThis.IntersectionObserver
  }
})

test("infinite scroll aborts stale requests when content is replaced", async () => {
  const originalDocument = globalThis.document
  const originalFetch = globalThis.fetch
  const firstFixture = buildFixture()
  let resolveFetch
  let requestSignal

  globalThis.fetch = (_url, options) => {
    requestSignal = options.signal
    return new Promise((resolve) => {
      resolveFetch = resolve
    })
  }

  globalThis.document = firstFixture.document
  try {
    setupAdminInfiniteScroll()
    const firstObserver = firstFixture.observer()
    firstObserver.callback([{ isIntersecting: true }])

    const secondFixture = buildFixture()
    globalThis.document = secondFixture.document

    setupAdminInfiniteScroll()

    assert.equal(firstObserver.disconnected, true)
    assert.equal(requestSignal.aborted, true)
    assert.equal(secondFixture.observer().disconnected, false)

    resolveFetch({ ok: true, json: async () => ({ html: "<tr></tr>", next_url: null }) })
    await waitForAsyncWork()
    assert.deepEqual(firstFixture.rows.insertedHtml, [])
  } finally {
    globalThis.document = originalDocument
    globalThis.fetch = originalFetch
    delete globalThis.IntersectionObserver
  }
})
