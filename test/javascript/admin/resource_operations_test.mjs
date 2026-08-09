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
    `const selectedAdminResourceIds = () => []
const setupAdminResourceSelection = () => {}
const updateResourceSelectionState = () => {}
const setupAdminOperationModal = () => {}
class AdminOperationProgress {
  constructor({ form }) {
    this.form = form
    this.phase = "waiting"
  }

  start() {
    this.form.dataset.adminOperationBusy = "true"
  }

  reset() {}
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
