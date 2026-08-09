import {
  selectedAdminResourceIds,
  setupAdminResourceSelection,
  updateAdminResourceSelectionState as updateResourceSelectionState,
} from "./resource_selection"
import { rememberAdminDialogFocus } from "./dialog_focus"
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

const requestFailureMessage = (status) => `リクエストに失敗しました（HTTP ${status}）。`

const updateAdminOperationSubmitStates = () => {
  document.querySelectorAll(adminSelectors.operationForm).forEach((form) => {
    const submitButton = form.querySelector(adminSelectors.operationSubmit)
    const submitNote = form.querySelector(adminSelectors.operationSubmitNote)
    if (!submitButton) return

    const busy = form.dataset.adminOperationBusy === "true"
    const selectionRequired = form.dataset.adminOperationSelectionRequired === "true"
    const selectionReady = !selectionRequired || selectedAdminResourceIds().length > 0
    const inputsReady = adminOperationRequiredInputsReady(form)
    submitButton.disabled = busy || !selectionReady || !inputsReady

    if (!submitNote) return

    if (busy) {
      submitNote.textContent = "処理中です。完了するまで待ってください。"
    } else if (!selectionReady) {
      submitNote.textContent = "対象を選択すると実行できます。"
    } else if (!inputsReady) {
      submitNote.textContent = "必須項目を入力すると実行できます。"
    } else {
      submitNote.textContent = "内容を確認して実行できます。"
    }
  })
}

export const updateAdminResourceSelectionState = () => updateResourceSelectionState({ afterUpdate: updateAdminOperationSubmitStates })

const setupAdminOperationForms = () => {
  document.querySelectorAll(adminSelectors.operationForm).forEach((form) => {
    if (form.dataset.initialized === "true") return

    form.dataset.initialized = "true"
    const dialog = document.querySelector(adminSelectors.operationConfirmDialog)
    const dialogMessage = dialog?.querySelector(adminSelectors.operationDialogMessage)
    const dialogTitle = dialog?.querySelector(adminSelectors.operationDialogTitle)
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
      if (form.dataset.adminOperationBusy === "true") return

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
        if (!response.ok) throw new Error(payload.message || requestFailureMessage(response.status))

        operationProgress.applyServerProgress(payload.progress)
      } catch (error) {
        console.error(error)
        operationProgress.fail(error.message || "処理中にエラーが発生しました。")
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

      if (form.dataset.adminOperationBusy === "true") {
        event.preventDefault()
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

      const operationLabel = form.dataset.adminOperationLabel || "アクション"
      const resourceLabel = form.dataset.adminOperationResourceLabel || "対象"
      const targetLabel = form.dataset.adminOperationTargetLabel || "この画面の対象"
      const messageParts = [form.dataset.confirmation || `${operationLabel}を実行します。よろしいですか？`]
      if (form.dataset.adminOperationSelection === "true") {
        const selectedCount = selectedAdminResourceIds().length
        messageParts.push(selectedCount > 0 ? `${resourceLabel}: 選択中 ${selectedCount.toLocaleString()}件` : `${resourceLabel}: ${targetLabel}`)
      } else {
        messageParts.push(`${resourceLabel}: ${targetLabel}`)
      }
      const message = messageParts.join("\n")
      if (!dialog?.showModal) {
        if (window.confirm(message)) submitConfirmed()
        return
      }

      if (dialogTitle) dialogTitle.textContent = `${operationLabel}を実行しますか？`
      if (dialogMessage) dialogMessage.textContent = message
      rememberAdminDialogFocus(dialog)
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
