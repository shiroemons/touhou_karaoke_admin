import assert from "node:assert/strict"
import { readFile } from "node:fs/promises"
import { test } from "node:test"

const source = await readFile(new URL("../../../app/javascript/admin/navigation.js", import.meta.url), "utf8")
const moduleUrl = `data:text/javascript;base64,${Buffer.from(source).toString("base64")}`
const { fetchAndReplaceAdminPage, isAdminAbortError, replaceAdminPage, replaceAdminResourceContent } = await import(moduleUrl)

test("abort error detection tolerates non-error rejection values", () => {
  assert.equal(isAdminAbortError(null), false)
  assert.equal(isAdminAbortError("aborted"), false)
  assert.equal(isAdminAbortError({ name: "AbortError" }), true)
})

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
    assert.equal(content.attributes["aria-busy"], "false")
  } finally {
    globalThis.document = originalDocument
    globalThis.fetch = originalFetch
    globalThis.window = originalWindow
  }
})

test("resource content navigation ignores a stale response even when abort is ignored", async () => {
  const originalDocument = globalThis.document
  const originalFetch = globalThis.fetch
  const originalWindow = globalThis.window
  const content = new FakeContent()
  content.outerHTML = "<main>initial</main>"
  const requests = []

  globalThis.document = { querySelector: () => content }
  globalThis.window = {
    location: { origin: "http://example.test" },
    history: { pushState: () => {} },
  }
  globalThis.fetch = (url, options) => new Promise((resolve) => {
    requests.push({ options, resolve, url })
  })

  try {
    const firstRequestPromise = replaceAdminResourceContent("/admin/songs?q=old")
    const secondRequestPromise = replaceAdminResourceContent("/admin/songs?q=new")

    requests[0].resolve({
      ok: true,
      json: async () => ({ html: "<main>old</main>" }),
    })
    await firstRequestPromise
    assert.equal(content.outerHTML, "<main>initial</main>")

    requests[1].resolve({
      ok: true,
      json: async () => ({ html: "<main>new</main>" }),
    })
    await secondRequestPromise
    assert.equal(content.outerHTML, "<main>new</main>")
  } finally {
    globalThis.document = originalDocument
    globalThis.fetch = originalFetch
    globalThis.window = originalWindow
  }
})

test("resource content navigation keeps the current content for a malformed response", async () => {
  const originalDocument = globalThis.document
  const originalFetch = globalThis.fetch
  const originalWindow = globalThis.window
  const content = new FakeContent()
  content.outerHTML = "<main>initial</main>"

  globalThis.document = { querySelector: () => content }
  globalThis.window = {
    location: { origin: "http://example.test" },
    history: { pushState: () => {} },
  }
  globalThis.fetch = async () => ({
    ok: true,
    json: async () => ({ html: null }),
  })

  try {
    await assert.rejects(
      replaceAdminResourceContent("/admin/songs?q=malformed"),
      /一覧データの形式が不正です。/
    )
    assert.equal(content.outerHTML, "<main>initial</main>")
    assert.equal(content.attributes["aria-busy"], "false")
  } finally {
    globalThis.document = originalDocument
    globalThis.fetch = originalFetch
    globalThis.window = originalWindow
  }
})

test("full page navigation ignores a stale response even when abort is ignored", async () => {
  const originalDocument = globalThis.document
  const originalFetch = globalThis.fetch
  const originalWindow = globalThis.window
  const originalDOMParser = globalThis.DOMParser
  const currentContent = new FakeContent()
  let currentPageContent = currentContent
  let resolveFirstResponseText
  const requests = []

  currentContent.replaceWith = (replacement) => {
    currentPageContent = replacement
  }
  globalThis.document = {
    body: { dataset: {} },
    title: "現在のページ",
    querySelector: (selector) => selector === "[data-admin-page-content]" ? currentPageContent : null,
  }
  globalThis.window = {
    location: { origin: "http://example.test" },
    history: { pushState: () => {} },
  }
  globalThis.DOMParser = class DOMParser {
    parseFromString(html) {
      const nextContent = new FakeContent()
      nextContent.scrollTo = () => {}
      const nextDocument = {
        title: html.includes("new") ? "新しいページ" : "古いページ",
        querySelector: (selector) => selector === "[data-admin-page-content]" ? nextContent : null,
      }
      return nextDocument
    }
  }
  globalThis.fetch = (url, options) => new Promise((resolve) => {
    requests.push({ options, resolve, url })
  })

  try {
    const firstNavigation = fetchAndReplaceAdminPage("/admin/songs?query=old")
    requests[0].resolve({
      ok: true,
      text: () => new Promise((resolve) => {
        resolveFirstResponseText = resolve
      }),
      url: "http://example.test/admin/songs?query=old",
    })
    await Promise.resolve()

    const secondNavigation = fetchAndReplaceAdminPage("/admin/songs?query=new")
    assert.equal(requests[0].options.signal.aborted, true)

    resolveFirstResponseText("<html>old</html>")
    await firstNavigation
    assert.equal(currentPageContent, currentContent)

    requests[1].resolve({
      ok: true,
      text: async () => "<html>new</html>",
      url: "http://example.test/admin/songs?query=new",
    })
    await secondNavigation
    assert.notEqual(currentPageContent, currentContent)
    assert.equal(globalThis.document.title, "新しいページ")
  } finally {
    globalThis.document = originalDocument
    globalThis.fetch = originalFetch
    globalThis.window = originalWindow
    globalThis.DOMParser = originalDOMParser
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
  let scrollPosition
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
    scrollTo: (position) => { scrollPosition = position },
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
    assert.deepEqual(scrollPosition, { top: 0, left: 0 })
  } finally {
    globalThis.document = originalDocument
    globalThis.window = originalWindow
    globalThis.DOMParser = originalDOMParser
  }
})
