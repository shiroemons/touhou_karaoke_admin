import assert from "node:assert/strict"
import { readFile } from "node:fs/promises"
import { test } from "node:test"

const source = await readFile(new URL("../../../app/javascript/admin/operation_progress.js", import.meta.url), "utf8")
const moduleUrl = `data:text/javascript;base64,${Buffer.from(source).toString("base64")}`
const { AdminOperationProgress } = await import(moduleUrl)

class FakeClassList {
  constructor() {
    this.values = new Set()
  }

  add(value) {
    this.values.add(value)
  }

  remove(value) {
    this.values.delete(value)
  }

  toggle(value, force) {
    if (force) {
      this.add(value)
    } else {
      this.remove(value)
    }
  }

  has(value) {
    return this.values.has(value)
  }
}

class FakeElement {
  constructor({ dataset = {}, hidden = false } = {}) {
    this.dataset = dataset
    this.hidden = hidden
    this.disabled = false
    this.textContent = ""
    this.style = {}
    this.classList = new FakeClassList()
    this.attributes = {}
  }

  setAttribute(name, value) {
    this.attributes[name] = value
  }
}

const buildProgress = () => {
  const form = new FakeElement()
  const modalCancelButton = new FakeElement()
  const submitButton = new FakeElement()
  const progressBar = new FakeElement()
  const progressStatus = new FakeElement()
  const progressLabel = new FakeElement()
  const progressPercent = new FakeElement()
  const progressbar = new FakeElement()
  const progressElapsed = new FakeElement()
  const progressSteps = [
    new FakeElement({ dataset: { adminOperationStep: "prepare" } }),
    new FakeElement({ dataset: { adminOperationStep: "execute" } }),
    new FakeElement({ dataset: { adminOperationStep: "finish" } }),
  ]
  let updateCalls = 0

  const progress = new AdminOperationProgress({
    form,
    operationModal: { open: false },
    progress: new FakeElement(),
    progressLabel,
    progressPercent,
    progressStatus,
    progressElapsed,
    progressbar,
    progressBar,
    progressSteps,
    modalCancelButton,
    submitButton,
    inlineConfirmation: false,
    progressUrl: undefined,
    estimatedSeconds: 40,
    updateSubmitStates: () => {
      updateCalls += 1
    },
  })

  return {
    form,
    modalCancelButton,
    progress,
    progressBar,
    progressLabel,
    progressPercent,
    progressStatus,
    progressbar,
    submitButton,
    updateCalls: () => updateCalls,
  }
}

test("AdminOperationProgress.fail falls back to an actionable failed state", () => {
  const { form, modalCancelButton, progress, progressBar, progressLabel, progressStatus, submitButton, updateCalls } = buildProgress()

  form.dataset.adminOperationBusy = "true"
  form.dataset.confirmed = "true"
  modalCancelButton.disabled = true
  submitButton.disabled = true
  progressBar.classList.add("admin-operation-progress-bar-active")

  progress.fail("Request failed: 500")

  assert.equal(progress.phase, "failed")
  assert.equal(progressStatus.textContent, "エラー")
  assert.equal(progressLabel.textContent, "Request failed: 500")
  assert.equal(form.dataset.adminOperationBusy, undefined)
  assert.equal(form.dataset.confirmed, undefined)
  assert.equal(modalCancelButton.disabled, false)
  assert.equal(progressBar.classList.has("admin-operation-progress-bar-active"), false)
  assert.equal(updateCalls(), 1)
})

test("AdminOperationProgress.applyServerProgress handles failed server state", () => {
  const { form, modalCancelButton, progress, progressBar, progressLabel, progressPercent, progressStatus, progressbar } = buildProgress()

  form.dataset.adminOperationBusy = "true"
  modalCancelButton.disabled = true
  progressBar.classList.add("admin-operation-progress-bar-active")

  progress.applyServerProgress({
    state: "failed",
    percentage: 42,
    status: "失敗",
    label: "外部サイト取得に失敗しました",
    detail: "接続できませんでした",
  })

  assert.equal(progress.phase, "failed")
  assert.equal(progressStatus.textContent, "エラー")
  assert.equal(progressLabel.textContent, "接続できませんでした")
  assert.equal(progressPercent.textContent, "42%")
  assert.equal(progressbar.attributes["aria-valuenow"], "42")
  assert.equal(form.dataset.adminOperationBusy, undefined)
  assert.equal(modalCancelButton.disabled, false)
  assert.equal(progressBar.classList.has("admin-operation-progress-bar-active"), false)
})
