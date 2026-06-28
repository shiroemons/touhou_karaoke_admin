import {
  selectedAdminResourceIds,
  setupAdminResourceSelection,
  updateAdminResourceSelectionState as updateResourceSelectionState,
} from "./resource_selection"
import { setupAdminOperationModal } from "./operation_modal"
import { AdminOperationProgress } from "./operation_progress"

const adminOperationRequiredInputsReady = (form) =>
  Array.from(form.querySelectorAll("[data-admin-operation-required-input]")).every((input) => {
    if (input.type === "file") return input.files.length > 0

    return input.value.trim().length > 0
  })

const adminOperationFormReady = (form) => {
  const selectionRequired = form.dataset.adminOperationSelectionRequired === "true"
  const selectionReady = !selectionRequired || selectedAdminResourceIds().length > 0

  return selectionReady && adminOperationRequiredInputsReady(form)
}

const updateAdminOperationSubmitStates = () => {
  document.querySelectorAll("[data-admin-operation-form]").forEach((form) => {
    const submitButton = form.querySelector("[data-admin-operation-submit]")
    if (!submitButton) return

    submitButton.disabled = form.dataset.adminOperationBusy === "true" || !adminOperationFormReady(form)
  })
}

export const updateAdminResourceSelectionState = () => updateResourceSelectionState({ afterUpdate: updateAdminOperationSubmitStates })

const setupAdminOperationForms = () => {
  document.querySelectorAll("[data-admin-operation-form]").forEach((form) => {
    if (form.dataset.initialized === "true") return

    form.dataset.initialized = "true"
    const dialog = document.querySelector("[data-admin-operation-confirm-dialog]")
    const dialogMessage = dialog?.querySelector("[data-admin-operation-dialog-message]")
    const confirmButton = dialog?.querySelector("[data-admin-operation-confirm]")
    const cancelButton = dialog?.querySelector("[data-admin-operation-cancel]")
    const inlineConfirmation = form.dataset.adminOperationInlineConfirmation === "true"
    const asyncOperation = form.dataset.adminOperationAsync === "true"
    const operationModal = form.closest("[data-admin-operation-modal]")
    const operationPanel = form.closest("[data-admin-operation-panel]")
    const selectedIdsContainer = form.querySelector("[data-admin-operation-selected-ids]")
    const modalCancelButton = form.querySelector("[data-admin-operation-modal-cancel]")
    const submitButton = form.querySelector("[data-admin-operation-submit]")
    const progress = form.querySelector("[data-admin-operation-progress]")
    const progressLabel = form.querySelector("[data-admin-operation-progress-label]")
    const progressPercent = form.querySelector("[data-admin-operation-progress-percent]")
    const progressStatus = form.querySelector("[data-admin-operation-progress-status]")
    const progressElapsed = form.querySelector("[data-admin-operation-progress-elapsed]")
    const progressbar = form.querySelector("[data-admin-operation-progressbar]")
    const progressBar = form.querySelector("[data-admin-operation-progress-bar]")
    const progressSteps = form.querySelectorAll("[data-admin-operation-step]")
    const progressUrl = form.dataset.adminOperationProgressUrl
    const parsedEstimatedSeconds = Number.parseInt(form.dataset.adminOperationEstimatedSeconds || "40", 10)
    const estimatedSeconds = Number.isFinite(parsedEstimatedSeconds) && parsedEstimatedSeconds > 0 ? parsedEstimatedSeconds : 40
    const operationProgress = new AdminOperationProgress({
      form,
      operationModal,
      progress,
      progressLabel,
      progressPercent,
      progressStatus,
      progressElapsed,
      progressbar,
      progressBar,
      progressSteps,
      modalCancelButton,
      submitButton,
      inlineConfirmation,
      progressUrl,
      estimatedSeconds,
      updateSubmitStates: updateAdminOperationSubmitStates,
    })

    const submitAsyncOperation = async () => {
      syncSelectedIds()
      operationProgress.start()

      try {
        const csrfToken = document.querySelector("meta[name='csrf-token']")?.getAttribute("content")
        const response = await fetch(form.action, {
          method: form.method.toUpperCase(),
          headers: {
            Accept: "application/json",
            "X-Requested-With": "XMLHttpRequest",
            ...(csrfToken ? { "X-CSRF-Token": csrfToken } : {}),
          },
          body: new FormData(form),
          credentials: "same-origin",
        })

        const payload = await response.json().catch(() => ({}))
        if (!response.ok) throw new Error(payload.message || `Request failed: ${response.status}`)

        operationProgress.applyServerProgress(payload.progress)
      } catch (error) {
        console.error(error)
        operationProgress.fail(error.message)
      }
    }

    const syncSelectedIds = () => {
      if (!selectedIdsContainer) return

      selectedIdsContainer.replaceChildren()
      selectedAdminResourceIds().forEach((id) => {
        const input = document.createElement("input")
        input.type = "hidden"
        input.name = "selected_ids[]"
        input.value = id
        selectedIdsContainer.appendChild(input)
      })
    }

    const submitConfirmed = () => {
      form.dataset.confirmed = "true"
      form.requestSubmit(submitButton || undefined)
    }

    form.addEventListener("submit", (event) => {
      if (!adminOperationFormReady(form)) {
        event.preventDefault()
        updateAdminOperationSubmitStates()
        return
      }

      if (form.dataset.confirmed === "true") {
        syncSelectedIds()
        if (asyncOperation) {
          event.preventDefault()
          submitAsyncOperation()
          return
        }
        operationProgress.start()
        return
      }

      if (inlineConfirmation) {
        syncSelectedIds()
        if (asyncOperation) {
          event.preventDefault()
          submitAsyncOperation()
          return
        }
        operationProgress.start()
        return
      }

      event.preventDefault()

      const message = form.dataset.confirmation || "アクションを実行します。よろしいですか？"
      if (!dialog?.showModal) {
        if (window.confirm(message)) submitConfirmed()
        return
      }

      if (dialogMessage) dialogMessage.textContent = message
      dialog.showModal()
    })

    confirmButton?.addEventListener("click", () => {
      dialog?.close()
      submitConfirmed()
    })

    cancelButton?.addEventListener("click", () => {
      dialog?.close()
    })

    modalCancelButton?.addEventListener("click", () => {
      operationModal?.close()
    })

    form.querySelectorAll("[data-admin-operation-required-input]").forEach((input) => {
      input.addEventListener("input", updateAdminOperationSubmitStates)
      input.addEventListener("change", updateAdminOperationSubmitStates)
    })

    operationModal?.addEventListener("close", () => {
      if (operationProgress.phase !== "waiting") operationProgress.reset()
    })

    operationPanel?.addEventListener("admin-operation-panel-open", () => {
      operationProgress.reset()
    })

    updateAdminOperationSubmitStates()
  })
}


export const setupAdminResourceOperations = () => {
  setupAdminResourceSelection({ afterUpdate: updateAdminOperationSubmitStates })
  setupAdminOperationModal({ updateSelectionState: updateAdminResourceSelectionState })
  setupAdminOperationForms()
}
