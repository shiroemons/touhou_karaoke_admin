import {
  selectedAdminResourceIds,
  setupAdminResourceSelection,
  updateAdminResourceSelectionState as updateResourceSelectionState,
} from "./resource_selection"
import { setupAdminOperationModal } from "./operation_modal"
import { AdminOperationProgress } from "./operation_progress"
import { adminSelectors } from "./selectors"

const adminOperationRequiredInputsReady = (form) =>
  Array.from(form.querySelectorAll(adminSelectors.operationRequiredInput)).every((input) => {
    if (input.type === "file") return input.files.length > 0

    return input.value.trim().length > 0
  })

const adminOperationFormReady = (form) => {
  const selectionRequired = form.dataset.adminOperationSelectionRequired === "true"
  const selectionReady = !selectionRequired || selectedAdminResourceIds().length > 0

  return selectionReady && adminOperationRequiredInputsReady(form)
}

const updateAdminOperationSubmitStates = () => {
  document.querySelectorAll(adminSelectors.operationForm).forEach((form) => {
    const submitButton = form.querySelector(adminSelectors.operationSubmit)
    if (!submitButton) return

    submitButton.disabled = form.dataset.adminOperationBusy === "true" || !adminOperationFormReady(form)
  })
}

export const updateAdminResourceSelectionState = () => updateResourceSelectionState({ afterUpdate: updateAdminOperationSubmitStates })

const setupAdminOperationForms = () => {
  document.querySelectorAll(adminSelectors.operationForm).forEach((form) => {
    if (form.dataset.initialized === "true") return

    form.dataset.initialized = "true"
    const dialog = document.querySelector(adminSelectors.operationConfirmDialog)
    const dialogMessage = dialog?.querySelector(adminSelectors.operationDialogMessage)
    const confirmButton = dialog?.querySelector(adminSelectors.operationConfirm)
    const cancelButton = dialog?.querySelector(adminSelectors.operationCancel)
    const inlineConfirmation = form.dataset.adminOperationInlineConfirmation === "true"
    const asyncOperation = form.dataset.adminOperationAsync === "true"
    const operationModal = form.closest(adminSelectors.operationModal)
    const operationPanel = form.closest(adminSelectors.operationPanel)
    const selectedIdsContainer = form.querySelector(adminSelectors.operationSelectedIds)
    const modalCancelButton = form.querySelector(adminSelectors.operationModalCancel)
    const submitButton = form.querySelector(adminSelectors.operationSubmit)
    const progress = form.querySelector(adminSelectors.operationProgress)
    const progressLabel = form.querySelector(adminSelectors.operationProgressLabel)
    const progressPercent = form.querySelector(adminSelectors.operationProgressPercent)
    const progressStatus = form.querySelector(adminSelectors.operationProgressStatus)
    const progressElapsed = form.querySelector(adminSelectors.operationProgressElapsed)
    const progressbar = form.querySelector(adminSelectors.operationProgressbar)
    const progressBar = form.querySelector(adminSelectors.operationProgressBar)
    const progressSteps = form.querySelectorAll(adminSelectors.operationStep)
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
        const csrfToken = document.querySelector(adminSelectors.csrfToken)?.getAttribute("content")
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

    form.querySelectorAll(adminSelectors.operationRequiredInput).forEach((input) => {
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
