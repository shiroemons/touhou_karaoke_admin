import assert from "node:assert/strict"
import { readFile } from "node:fs/promises"
import { test } from "node:test"

const source = await readFile(new URL("../../../app/javascript/admin/workflow_runner.js", import.meta.url), "utf8")
const moduleUrl = `data:text/javascript;base64,${Buffer.from(source).toString("base64")}`
const { setupAdminWorkflowRunner } = await import(moduleUrl)

class FakeElement {
  constructor({ children = [], dataset = {}, queryResults = {} } = {}) {
    this.children = children
    this.dataset = dataset
    this.queryResults = queryResults
    this.textContent = ""
    this.hidden = false
    this.isConnected = true
  }

  querySelector(selector) {
    return this.queryResults[selector] || null
  }

  querySelectorAll() {
    return this.children
  }
}

const buildFixture = ({ progressUrl = "/admin/workflow/dam/progress?run_id=run", steps = [] } = {}) => {
  const runner = new FakeElement({
    children: steps,
    dataset: {
      adminWorkflowRunId: "run",
      adminWorkflowProgressUrl: progressUrl,
      adminWorkflowState: "running",
    },
  })
  const statusPanel = new FakeElement()
  const statusLabel = new FakeElement()
  const statusState = new FakeElement()
  const statusPercent = new FakeElement()
  const statusCurrent = new FakeElement()
  const statusCount = new FakeElement()
  const currentStepLabel = new FakeElement()
  const document = {
    querySelectorAll: () => [runner],
    querySelector: (selector) => (selector === "[data-admin-workflow-status]" ? statusPanel : null),
  }
  statusPanel.querySelector = (selector) => ({
    "[data-admin-workflow-status-label]": statusLabel,
    "[data-admin-workflow-status-state]": statusState,
    "[data-admin-workflow-status-percent]": statusPercent,
    "[data-admin-workflow-status-current]": statusCurrent,
    "[data-admin-workflow-status-count]": statusCount,
  })[selector] || null
  runner.querySelector = (selector) => (selector === "[data-admin-workflow-current-step]" ? currentStepLabel : null)

  return {
    currentStepLabel,
    document,
    runner,
    statusLabel,
    statusState,
    statusCurrent,
    statusPercent,
    statusCount,
  }
}

const waitForPoll = () => new Promise((resolve) => setImmediate(resolve))

test("workflow runner stops polling and displays an unknown state for a missing run", async () => {
  const originalDocument = globalThis.document
  const originalFetch = globalThis.fetch
  const originalWindow = globalThis.window
  let scheduledPolls = 0

  globalThis.fetch = async () => ({ ok: false, status: 404 })
  globalThis.window = {
    setTimeout: () => {
      scheduledPolls += 1
      return scheduledPolls
    },
    clearTimeout: () => {},
  }
  const fixture = buildFixture()
  globalThis.document = fixture.document

  try {
    setupAdminWorkflowRunner()
    await waitForPoll()

    assert.equal(fixture.runner.dataset.adminWorkflowState, "unknown")
    assert.equal(fixture.statusState.textContent, "状態不明")
    assert.match(fixture.statusLabel.textContent, /再読み込みしてください/)
    assert.equal(fixture.statusCurrent.textContent, "確認できません")
    assert.equal(scheduledPolls, 0)
  } finally {
    globalThis.document = originalDocument
    globalThis.fetch = originalFetch
    globalThis.window = originalWindow
  }
})

test("workflow runner retries transient failures with bounded backoff", async () => {
  const originalDocument = globalThis.document
  const originalFetch = globalThis.fetch
  const originalWindow = globalThis.window
  let calls = 0
  const scheduled = []

  globalThis.fetch = async () => {
    calls += 1
    throw new Error("network error")
  }
  globalThis.window = {
    setTimeout: (callback, delay) => {
      scheduled.push({ callback, delay })
      return scheduled.length
    },
    clearTimeout: () => {},
  }
  const fixture = buildFixture()
  globalThis.document = fixture.document

  try {
    setupAdminWorkflowRunner()
    await waitForPoll()

    assert.equal(calls, 1)
    assert.equal(fixture.statusState.textContent, "再試行中")
    assert.match(fixture.statusLabel.textContent, /1\/3回目/)
    assert.equal(scheduled.at(-1).delay, 1500)

    await scheduled.at(-1).callback()
    await waitForPoll()
    assert.equal(calls, 2)
    assert.equal(scheduled.at(-1).delay, 3000)

    await scheduled.at(-1).callback()
    await waitForPoll()
    assert.equal(calls, 3)
    assert.equal(fixture.runner.dataset.adminWorkflowState, "failed")
    assert.equal(fixture.statusState.textContent, "エラー")
    assert.match(fixture.statusLabel.textContent, /再読み込みしてください/)
    assert.equal(scheduled.length, 2)
  } finally {
    globalThis.document = originalDocument
    globalThis.fetch = originalFetch
    globalThis.window = originalWindow
  }
})

test("workflow runner retries a malformed progress payload", async () => {
  const originalDocument = globalThis.document
  const originalFetch = globalThis.fetch
  const originalWindow = globalThis.window
  const scheduled = []

  globalThis.fetch = async () => ({ ok: true, json: async () => null })
  globalThis.window = {
    setTimeout: (callback, delay) => {
      scheduled.push({ callback, delay })
      return scheduled.length
    },
    clearTimeout: () => {},
  }
  const fixture = buildFixture()
  globalThis.document = fixture.document

  try {
    setupAdminWorkflowRunner()
    await waitForPoll()

    assert.equal(fixture.runner.dataset.adminWorkflowState, "retrying")
    assert.equal(fixture.statusState.textContent, "再試行中")
    assert.match(fixture.statusLabel.textContent, /1\/3回目/)
    assert.equal(scheduled.at(-1).delay, 1500)
  } finally {
    globalThis.document = originalDocument
    globalThis.fetch = originalFetch
    globalThis.window = originalWindow
  }
})

test("workflow runner normalizes malformed progress numbers", async () => {
  const originalDocument = globalThis.document
  const originalFetch = globalThis.fetch
  const originalWindow = globalThis.window

  globalThis.fetch = async () => ({
    ok: true,
    json: async () => ({
      state: "running",
      status: "実行中",
      percentage: "not-a-number",
      workflow: {
        completed_steps: "12",
        total_steps: "3",
        steps: [],
      },
    }),
  })
  globalThis.window = {
    setTimeout: () => "poll",
    clearTimeout: () => {},
  }
  const fixture = buildFixture()
  globalThis.document = fixture.document

  try {
    setupAdminWorkflowRunner()
    await waitForPoll()

    assert.equal(fixture.statusPercent.textContent, "0%")
    assert.equal(fixture.statusCount.textContent, "3 / 3")
  } finally {
    globalThis.document = originalDocument
    globalThis.fetch = originalFetch
    globalThis.window = originalWindow
  }
})

test("workflow runner labels unknown step statuses safely", async () => {
  const originalDocument = globalThis.document
  const originalFetch = globalThis.fetch
  const originalWindow = globalThis.window
  const stepProgress = new FakeElement()
  const step = new FakeElement({
    dataset: { adminWorkflowStep: "stage:branch:step" },
    queryResults: { "[data-admin-workflow-step-progress]": stepProgress },
  })

  globalThis.fetch = async () => ({
    ok: true,
    json: async () => ({
      state: "running",
      workflow: {
        steps: [{ key: "stage:branch:step", status: "unexpected-status" }],
      },
    }),
  })
  globalThis.window = {
    setTimeout: () => "poll",
    clearTimeout: () => {},
  }
  const fixture = buildFixture({ steps: [step] })
  globalThis.document = fixture.document

  try {
    setupAdminWorkflowRunner()
    await waitForPoll()

    assert.equal(step.dataset.adminWorkflowStatus, "unknown")
    assert.equal(stepProgress.textContent, "状態不明")
  } finally {
    globalThis.document = originalDocument
    globalThis.fetch = originalFetch
    globalThis.window = originalWindow
  }
})

test("workflow runner stops polling after its runner is detached", async () => {
  const originalDocument = globalThis.document
  const originalFetch = globalThis.fetch
  const originalWindow = globalThis.window
  const pagehideHandlers = new Set()
  let calls = 0
  const scheduled = []
  const cleared = []

  globalThis.fetch = async () => {
    calls += 1
    throw new Error("network error")
  }
  globalThis.window = {
    addEventListener: (type, handler) => {
      if (type === "pagehide") pagehideHandlers.add(handler)
    },
    removeEventListener: (type, handler) => {
      if (type === "pagehide") pagehideHandlers.delete(handler)
    },
    setTimeout: (callback, delay) => {
      scheduled.push({ callback, delay })
      return scheduled.length
    },
    clearTimeout: (timer) => {
      cleared.push(timer)
    },
  }
  const fixture = buildFixture()
  globalThis.document = fixture.document

  try {
    setupAdminWorkflowRunner()
    await waitForPoll()

    assert.equal(pagehideHandlers.size, 1)
    fixture.runner.isConnected = false
    await scheduled.at(-1).callback()

    assert.equal(calls, 1)
    assert.equal(scheduled.length, 1)
    assert.equal(pagehideHandlers.size, 0)
    assert.deepEqual(cleared, [1])
  } finally {
    globalThis.document = originalDocument
    globalThis.fetch = originalFetch
    globalThis.window = originalWindow
  }
})

test("workflow runner aborts an in-flight poll when the page is hidden", async () => {
  const originalDocument = globalThis.document
  const originalFetch = globalThis.fetch
  const originalWindow = globalThis.window
  const pagehideHandlers = new Set()
  let resolveResponse
  let requestOptions
  const scheduled = []

  globalThis.fetch = (_url, options) => {
    requestOptions = options
    return new Promise((resolve) => {
      resolveResponse = resolve
    })
  }
  globalThis.window = {
    addEventListener: (type, handler) => {
      if (type === "pagehide") pagehideHandlers.add(handler)
    },
    removeEventListener: (type, handler) => {
      if (type === "pagehide") pagehideHandlers.delete(handler)
    },
    setTimeout: (callback, delay) => {
      scheduled.push({ callback, delay })
      return scheduled.length
    },
    clearTimeout: () => {},
  }
  const fixture = buildFixture()
  globalThis.document = fixture.document

  try {
    setupAdminWorkflowRunner()
    await waitForPoll()

    assert.ok(requestOptions.signal)
    assert.equal(pagehideHandlers.size, 1)
    pagehideHandlers.values().next().value()
    assert.equal(requestOptions.signal.aborted, true)
    assert.equal(pagehideHandlers.size, 0)

    resolveResponse({
      ok: true,
      json: async () => ({ state: "running", workflow: { steps: [] } }),
    })
    await waitForPoll()

    assert.equal(fixture.statusState.textContent, "")
    assert.equal(scheduled.length, 0)
  } finally {
    globalThis.document = originalDocument
    globalThis.fetch = originalFetch
    globalThis.window = originalWindow
  }
})
