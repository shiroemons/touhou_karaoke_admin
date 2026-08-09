import assert from "node:assert/strict"
import { readFile } from "node:fs/promises"
import { test } from "node:test"

const source = await readFile(new URL("../../../app/javascript/admin/navigation.js", import.meta.url), "utf8")
const moduleUrl = `data:text/javascript;base64,${Buffer.from(source).toString("base64")}`
const { replaceAdminPage, replaceAdminResourceContent } = await import(moduleUrl)

class FakeContent {
  constructor({ children = [], containedElements = [], onReplace = null } = {}) {
    this.attributes = {}
    this.children = children
    this.containedElements = containedElements
    this.onReplace = onReplace
    this._outerHTML = "<main>old</main>"
    this.focused = false
  }

  get outerHTML() {
    return this._outerHTML
  }

  set outerHTML(value) {
    this._outerHTML = value
    this.onReplace?.()
  }

  contains(element) {
    return this.containedElements.includes(element)
  }

  querySelectorAll() {
    return this.children
  }

  focus() {
    this.focused = true
  }

  setAttribute(name, value) {
    this.attributes[name] = value
  }

  removeAttribute(name) {
    delete this.attributes[name]
  }
}

test("resource content navigation aborts stale requests and preserves the latest response", async () => {
  const originalDocument = globalThis.document
  const originalFetch = globalThis.fetch
  const originalWindow = globalThis.window
  const content = new FakeContent()
  const requests = []

  globalThis.document = { querySelector: () => content }
  globalThis.window = {
    location: { origin: "http://example.test" },
    history: { pushState: () => {} },
  }
  globalThis.fetch = (url, options) => new Promise((resolve, reject) => {
    const request = { options, reject, resolve, url }
    options.signal.addEventListener("abort", () => {
      const error = new Error("aborted")
      error.name = "AbortError"
      reject(error)
    }, { once: true })
    requests.push(request)
  })

  try {
    const firstRequestPromise = replaceAdminResourceContent("/admin/songs?q=old")
    const secondRequestPromise = replaceAdminResourceContent("/admin/songs?q=new")

    assert.equal(requests.length, 2)
    assert.equal(requests[0].options.signal.aborted, true)
    assert.equal(content.attributes["aria-busy"], "true")

    const firstError = await firstRequestPromise.catch((error) => error)
    assert.equal(firstError.name, "AbortError")

    requests[1].resolve({
      ok: true,
      json: async () => ({ html: "<main>new</main>" }),
    })
    await secondRequestPromise

    assert.equal(content.outerHTML, "<main>new</main>")
    assert.equal(content.attributes["aria-busy"], undefined)
  } finally {
    globalThis.document = originalDocument
    globalThis.fetch = originalFetch
    globalThis.window = originalWindow
  }
})

test("resource content navigation restores focus to the replaced form control", async () => {
  const originalDocument = globalThis.document
  const originalFetch = globalThis.fetch
  const originalWindow = globalThis.window
  const activeSearch = { id: "q", name: "q", type: "search", focused: false }
  const replacementSearch = {
    id: "q",
    name: "q",
    type: "search",
    focused: false,
    focus() {
      this.focused = true
    },
  }
  const replacementContent = new FakeContent({ children: [replacementSearch] })
  let currentContent
  currentContent = new FakeContent({
    containedElements: [activeSearch],
    onReplace: () => {
      currentContent = replacementContent
    },
  })
  const requests = []

  globalThis.document = {
    activeElement: activeSearch,
    querySelector: () => currentContent,
  }
  globalThis.window = {
    location: { origin: "http://example.test" },
    history: { pushState: () => {} },
  }
  globalThis.fetch = (url, options) => new Promise((resolve) => {
    requests.push({ options, resolve, url })
  })

  try {
    const navigationPromise = replaceAdminResourceContent("/admin/songs?q=focused")
    requests[0].resolve({
      ok: true,
      json: async () => ({ html: "<main>focused</main>" }),
    })
    await navigationPromise

    assert.equal(replacementSearch.focused, true)
    assert.equal(replacementContent.focused, false)
  } finally {
    globalThis.document = originalDocument
    globalThis.fetch = originalFetch
    globalThis.window = originalWindow
  }
})

test("full page navigation focuses the new main content", () => {
  const originalDocument = globalThis.document
  const originalWindow = globalThis.window
  const originalDOMParser = globalThis.DOMParser
  const nextContent = new FakeContent()
  const currentContent = new FakeContent()
  let currentPageContent = currentContent
  const nextDocument = {
    querySelector: () => null,
    title: "新しいページ",
  }

  currentContent.replaceWith = (replacement) => {
    assert.equal(replacement, nextContent)
    currentPageContent = replacement
  }
  nextContent.scrollTo = () => {}
  globalThis.document = {
    title: "現在のページ",
    querySelector: (selector) => selector === "[data-admin-page-content]" ? currentPageContent : null,
  }
  globalThis.window = {
    history: { pushState: () => {} },
    location: { origin: "http://example.test" },
  }
  globalThis.DOMParser = class DOMParser {
    parseFromString() {
      return nextDocument
    }
  }
  nextDocument.querySelector = (selector) => selector === "[data-admin-page-content]" ? nextContent : null

  try {
    replaceAdminPage("<html>new</html>", "/admin/songs")

    assert.equal(nextContent.focused, true)
  } finally {
    globalThis.document = originalDocument
    globalThis.window = originalWindow
    globalThis.DOMParser = originalDOMParser
  }
})
