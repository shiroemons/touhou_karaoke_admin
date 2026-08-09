import assert from "node:assert/strict"
import { readFile } from "node:fs/promises"
import { test } from "node:test"

const source = await readFile(new URL("../../../app/javascript/admin/navigation.js", import.meta.url), "utf8")
const moduleUrl = `data:text/javascript;base64,${Buffer.from(source).toString("base64")}`
const { createAdminRequestTimeout, setupAdminAsyncIndex, setupAdminMobileNavigation } = await import(moduleUrl)

class FakeElement {
  constructor({ dataset = {}, closestResults = {}, queryResults = {} } = {}) {
    this.dataset = dataset
    this.closestResults = closestResults
    this.queryResults = queryResults
    this.attributes = {}
    this.focused = false
    this.textContent = ""
  }

  closest(selector) {
    return this.closestResults[selector] || null
  }

  focus(options) {
    this.focused = true
    this.focusOptions = options
  }

  querySelector(selector) {
    return this.queryResults[selector] || null
  }

  setAttribute(name, value) {
    this.attributes[name] = value
  }
}

const buildFixture = () => {
  const label = new FakeElement()
  const sidebar = new FakeElement({
    queryResults: {
      "[data-admin-mobile-navigation-toggle]": null,
    },
  })
  const toggle = new FakeElement({
    closestResults: {
      "[data-admin-mobile-navigation-toggle]": null,
      ".admin-sidebar": sidebar,
    },
  })
  const navigationLink = new FakeElement({
    closestResults: {
      ".admin-nav-link, .admin-brand": null,
      ".admin-sidebar": sidebar,
    },
  })
  toggle.closestResults["[data-admin-mobile-navigation-toggle]"] = toggle
  navigationLink.closestResults[".admin-nav-link, .admin-brand"] = navigationLink
  sidebar.queryResults["[data-admin-mobile-navigation-toggle]"] = toggle
  sidebar.queryResults[".admin-nav-link"] = navigationLink
  toggle.queryResults["[data-admin-mobile-navigation-toggle-label]"] = label

  const document = {
    documentElement: { dataset: {} },
    eventListeners: {},
    addEventListener(type, callback) {
      this.eventListeners[type] ||= []
      this.eventListeners[type].push(callback)
    },
    dispatch(type, event) {
      ;(this.eventListeners[type] || []).forEach((callback) => callback(event))
    },
    querySelector: () => sidebar,
  }

  return { document, label, navigationLink, sidebar, toggle }
}

test("mobile navigation toggles state and accessible labels", () => {
  const fixture = buildFixture()
  globalThis.document = fixture.document
  setupAdminMobileNavigation()

  fixture.document.dispatch("click", { target: fixture.toggle })

  assert.equal(fixture.sidebar.dataset.adminMobileNavigationOpen, "true")
  assert.equal(fixture.toggle.attributes["aria-expanded"], "true")
  assert.equal(fixture.toggle.attributes["aria-label"], "メニューを閉じる")
  assert.equal(fixture.label.textContent, "閉じる")

  fixture.document.dispatch("click", { target: fixture.toggle })

  assert.equal(fixture.sidebar.dataset.adminMobileNavigationOpen, "false")
  assert.equal(fixture.toggle.attributes["aria-expanded"], "false")
  assert.equal(fixture.toggle.attributes["aria-label"], "メニューを開く")
  assert.equal(fixture.label.textContent, "メニュー")
})

test("opening mobile navigation moves focus to the first navigation link", () => {
  const fixture = buildFixture()
  globalThis.document = fixture.document
  setupAdminMobileNavigation()

  fixture.document.dispatch("click", { target: fixture.toggle })

  assert.equal(fixture.navigationLink.focused, true)
  assert.deepEqual(fixture.navigationLink.focusOptions, { preventScroll: true })
})

test("navigation link closes an open mobile menu", () => {
  const fixture = buildFixture()
  fixture.sidebar.dataset.adminMobileNavigationOpen = "true"
  globalThis.document = fixture.document
  setupAdminMobileNavigation()

  fixture.document.dispatch("click", { target: fixture.navigationLink })

  assert.equal(fixture.sidebar.dataset.adminMobileNavigationOpen, "false")
})

test("mobile navigation setup is idempotent", () => {
  const fixture = buildFixture()
  globalThis.document = fixture.document
  setupAdminMobileNavigation()
  setupAdminMobileNavigation()

  assert.equal(fixture.document.eventListeners.click.length, 1)
  assert.equal(fixture.document.eventListeners.keydown.length, 1)
})

test("async index setup is idempotent", () => {
  const originalDocument = globalThis.document
  const document = {
    documentElement: { dataset: {} },
    eventListeners: {},
    addEventListener(type, callback) {
      this.eventListeners[type] ||= []
      this.eventListeners[type].push(callback)
    },
  }

  globalThis.document = document

  try {
    setupAdminAsyncIndex()
    setupAdminAsyncIndex()

    assert.equal(document.eventListeners.click.length, 1)
    assert.equal(document.eventListeners.submit.length, 1)
    assert.equal(document.documentElement.dataset.adminAsyncIndexInitialized, "true")
  } finally {
    globalThis.document = originalDocument
  }
})

test("request timeout aborts the controller and can be cleared", () => {
  const originalWindow = globalThis.window
  let timeoutCallback
  let clearedTimeout
  let aborted = false
  globalThis.window = {
    clearTimeout: (timeoutId) => { clearedTimeout = timeoutId },
    setTimeout: (callback) => {
      timeoutCallback = callback
      return "timeout-id"
    },
  }

  try {
    const requestTimeout = createAdminRequestTimeout({ abort: () => { aborted = true } }, 100)

    assert.equal(requestTimeout.timedOut(), false)
    timeoutCallback()
    assert.equal(aborted, true)
    assert.equal(requestTimeout.timedOut(), true)
    requestTimeout.clear()
    assert.equal(clearedTimeout, "timeout-id")
  } finally {
    globalThis.window = originalWindow
  }
})
