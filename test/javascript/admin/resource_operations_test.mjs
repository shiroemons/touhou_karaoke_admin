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
  applyServerProgress() {}
  fail() {}
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
