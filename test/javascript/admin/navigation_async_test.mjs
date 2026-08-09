import assert from "node:assert/strict"
import { readFile } from "node:fs/promises"
import { test } from "node:test"

const source = await readFile(new URL("../../../app/javascript/admin/navigation.js", import.meta.url), "utf8")
const moduleUrl = `data:text/javascript;base64,${Buffer.from(source).toString("base64")}`
const { replaceAdminResourceContent } = await import(moduleUrl)

class FakeContent {
  constructor() {
    this.attributes = {}
    this.outerHTML = "<main>old</main>"
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
