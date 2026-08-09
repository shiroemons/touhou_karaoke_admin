import assert from "node:assert/strict"
import { readFile } from "node:fs/promises"
import { test } from "node:test"

const source = await readFile(new URL("../../../app/javascript/admin/resource_operations.js", import.meta.url), "utf8")
const moduleSource = source
  .replace(
    /^import \{ rememberAdminDialogFocus \} from "\.\/dialog_focus"\n/m,
    "const rememberAdminDialogFocus = () => {}\n"
  )
  .replace(
    /^import \{[\s\S]*?\} from "\.\/resource_selection"\nconst rememberAdminDialogFocus = \(\) => \{\}\nimport \{ setupAdminOperationModal \} from "\.\/operation_modal"\nimport \{ AdminOperationProgress \} from "\.\/operation_progress"\nimport \{ adminSelectors \} from "\.\/selectors"\n/m,
    `const rememberAdminDialogFocus = () => {}
const selectedAdminResourceIds = () => []
const setupAdminResourceSelection = () => {}
const updateResourceSelectionState = () => {}
const setupAdminOperationModal = () => {}
class AdminOperationProgress {
  constructor({ form }) {
    this.form = form
    this.phase = "waiting"
    this.sequence = 0
    this.activeSequence = 0
    this.controller = undefined
    form.operationProgress = this
  }

  start() {
    this.form.dataset.adminOperationBusy = "true"
    this.activeSequence = ++this.sequence
    this.controller = new AbortController()
    return { sequence: this.activeSequence, signal: this.controller.signal }
  }

  reset() {
    this.controller?.abort()
    this.activeSequence = 0
    delete this.form.dataset.adminOperationBusy
  }

  isCurrentOperation(operation) {
    return operation?.sequence === this.activeSequence
  }

  applyServerProgress(payload) {
    this.form.dataset.adminOperationProgress = payload ? "received" : "skipped"
  }

  fail(message) {
    this.form.dataset.adminOperationFailure = message
  }
}
const adminSelectors = {
  csrfToken: "meta[name='csrf-token']",
  operationCancel: "[data-admin-operation-cancel]",
  operationConfirm: "[data-admin-operation-confirm]",
  operationConfirmDialog: "[data-admin-operation-confirm-dialog]",
  operationDialogMessage: "[data-admin-operation-dialog-message]",
  operationDialogTitle: "[data-admin-operation-dialog-title]",
  operationForm: "[data-admin-operation-form]",
  operationModal: "[data-admin-operation-modal]",
  operationModalCancel: "[data-admin-operation-modal-cancel]",
  operationProgress: "[data-admin-operation-progress]",
  operationProgressAnnouncement: "[data-admin-operation-progress-announcement]",
  operationProgressBar: "[data-admin-operation-progress-bar]",
  operationProgressElapsed: "[data-admin-operation-progress-elapsed]",
  operationProgressLabel: "[data-admin-operation-progress-label]",
  operationProgressPercent: "[data-admin-operation-progress-percent]",
  operationProgressStatus: "[data-admin-operation-progress-status]",
  operationProgressbar: "[data-admin-operation-progressbar]",
  operationRequiredInput: "[data-admin-operation-required-input]",
  operationSelectionNote: "[data-admin-operation-selection-note]",
  operationSelectedIds: "[data-admin-operation-selected-ids]",
  operationStep: "[data-admin-operation-step]",
  operationSubmit: "[data-admin-operation-submit]",
  operationSubmitNote: "[data-admin-operation-submit-note]",
}
`
  )
const moduleUrl = `data:text/javascript;base64,${Buffer.from(moduleSource).toString("base64")}`
const { setupAdminResourceOperations } = await import(moduleUrl)

class FakeForm {
  constructor() {
    this.action = "/admin/songs/operation"
    this.dataset = {
      adminOperationAsync: "true",
      adminOperationInlineConfirmation: "true",
      adminOperationSelectionRequired: "false",
    }
    this.eventListeners = {}
    this.method = "post"
    this.submitButton = { disabled: false }
  }

  addEventListener(type, callback) {
    this.eventListeners[type] ||= []
    this.eventListeners[type].push(callback)
  }

  closest() {
    return null
  }

  querySelector(selector) {
    return selector === "[data-admin-operation-submit]" ? this.submitButton : null
  }

  querySelectorAll() {
    return []
  }

  dispatchSubmit() {
    const event = {
      defaultPrevented: false,
      preventDefault() {
        this.defaultPrevented = true
      },
    }
    this.eventListeners.submit.forEach((callback) => callback(event))
    return event
  }
}

class FakeButton {
  constructor() {
    this.eventListeners = {}
  }

  addEventListener(type, callback) {
    this.eventListeners[type] ||= []
    this.eventListeners[type].push(callback)
  }
}

class FakeDialog {
  constructor() {
    this.open = false
    this.showModalCalls = 0
    this.message = { textContent: "" }
    this.title = { textContent: "" }
    this.confirmButton = new FakeButton()
    this.cancelButton = new FakeButton()
  }

  querySelector(selector) {
    return {
      "[data-admin-operation-dialog-message]": this.message,
      "[data-admin-operation-dialog-title]": this.title,
      "[data-admin-operation-confirm]": this.confirmButton,
      "[data-admin-operation-cancel]": this.cancelButton,
    }[selector] || null
  }

  showModal() {
    this.showModalCalls += 1
    this.open = true
  }

  close() {
    this.open = false
  }
}

const waitForAsyncWork = () => new Promise((resolve) => setImmediate(resolve))

test("busy async operation forms reject duplicate submit events", () => {
  const originalDocument = globalThis.document
  const form = new FakeForm()
  globalThis.document = {
    querySelector: () => null,
    querySelectorAll: (selector) => (selector === "[data-admin-operation-form]" ? [form] : []),
  }

  try {
    form.dataset.adminOperationBusy = "true"
    setupAdminResourceOperations()

    const event = form.dispatchSubmit()

    assert.equal(event.defaultPrevented, true)
    assert.equal(form.eventListeners.submit.length, 1)
    assert.equal(form.submitButton.disabled, true)
  } finally {
    globalThis.document = originalDocument
  }
})

test("confirmation dialog ignores a duplicate submit while open", () => {
  const originalDocument = globalThis.document
  const form = new FakeForm()
  const dialog = new FakeDialog()
  form.dataset.adminOperationAsync = "false"
  form.dataset.adminOperationInlineConfirmation = "false"
  globalThis.document = {
    querySelector: (selector) => (selector === "[data-admin-operation-confirm-dialog]" ? dialog : null),
    querySelectorAll: (selector) => (selector === "[data-admin-operation-form]" ? [form] : []),
  }

  try {
    setupAdminResourceOperations()
    const firstEvent = form.dispatchSubmit()
    const secondEvent = form.dispatchSubmit()

    assert.equal(firstEvent.defaultPrevented, true)
    assert.equal(secondEvent.defaultPrevented, true)
    assert.equal(dialog.open, true)
    assert.equal(dialog.showModalCalls, 1)
    assert.match(dialog.message.textContent, /アクションを実行します/)
  } finally {
    globalThis.document = originalDocument
  }
})

test("async operation tolerates a null start response", async () => {
  const originalDocument = globalThis.document
  const originalFetch = globalThis.fetch
  const originalFormData = globalThis.FormData
  const form = new FakeForm()
  globalThis.document = {
    querySelector: () => null,
    querySelectorAll: (selector) => (selector === "[data-admin-operation-form]" ? [form] : []),
  }
  globalThis.fetch = async () => ({ ok: true, json: async () => null })
  globalThis.FormData = class {}

  try {
    setupAdminResourceOperations()
    const event = form.dispatchSubmit()
    await waitForAsyncWork()

    assert.equal(event.defaultPrevented, true)
    assert.equal(form.dataset.adminOperationProgress, "skipped")
    assert.equal(form.dataset.adminOperationFailure, undefined)
  } finally {
    globalThis.document = originalDocument
    globalThis.fetch = originalFetch
    globalThis.FormData = originalFormData
  }
})

test("async operation shows a fallback message for an invalid rejection", async () => {
  const originalDocument = globalThis.document
  const originalFetch = globalThis.fetch
  const originalFormData = globalThis.FormData
  const originalConsoleError = console.error
  const form = new FakeForm()
  globalThis.document = {
    querySelector: () => null,
    querySelectorAll: (selector) => (selector === "[data-admin-operation-form]" ? [form] : []),
  }
  globalThis.fetch = async () => {
    throw null
  }
  globalThis.FormData = class {}
  console.error = () => {}

  try {
    setupAdminResourceOperations()
    form.dispatchSubmit()
    await waitForAsyncWork()

    assert.equal(form.dataset.adminOperationFailure, "処理中にエラーが発生しました。")
  } finally {
    globalThis.document = originalDocument
    globalThis.fetch = originalFetch
    globalThis.FormData = originalFormData
    console.error = originalConsoleError
  }
})

test("async operation ignores a response after its progress is reset", async () => {
  const originalDocument = globalThis.document
  const originalFetch = globalThis.fetch
  const originalFormData = globalThis.FormData
  const form = new FakeForm()
  let resolveResponse
  let requestOptions
  globalThis.document = {
    querySelector: () => null,
    querySelectorAll: (selector) => (selector === "[data-admin-operation-form]" ? [form] : []),
  }
  globalThis.fetch = (_url, options) => {
    requestOptions = options
    return new Promise((resolve) => {
      resolveResponse = resolve
    })
  }
  globalThis.FormData = class {}

  try {
    setupAdminResourceOperations()
    form.dispatchSubmit()
    await waitForAsyncWork()

    assert.ok(requestOptions.signal)
    form.operationProgress.reset()
    assert.equal(requestOptions.signal.aborted, true)

    resolveResponse({ ok: true, json: async () => ({ progress: { state: "completed", percentage: 100 } }) })
    await waitForAsyncWork()

    assert.equal(form.dataset.adminOperationProgress, undefined)
    assert.equal(form.dataset.adminOperationFailure, undefined)
  } finally {
    globalThis.document = originalDocument
    globalThis.fetch = originalFetch
    globalThis.FormData = originalFormData
  }
})
