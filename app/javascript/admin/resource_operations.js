import {
  selectedAdminResourceIds,
  setupAdminResourceSelection,
  updateAdminResourceSelectionState as updateResourceSelectionState,
} from "./resource_selection"
import { setupAdminOperationModal } from "./operation_modal"

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
    let elapsedTimer
    let pollTimer
    let progressPhase = "waiting"
    let executeStartedAt
    let lastServerPercentage = 0
    let hasServerProgress = false
    let lastProgressStatus = "外部サイト取得中"
    let lastProgressLabel = "外部サイトから取得・保存しています..."
    let finishTimer

    const elapsedTime = (startedAt) => {
      const elapsedSeconds = Math.max(0, Math.floor((Date.now() - startedAt) / 1000))
      const minutes = Math.floor(elapsedSeconds / 60).toString().padStart(2, "0")
      const seconds = (elapsedSeconds % 60).toString().padStart(2, "0")
      return `${minutes}:${seconds}`
    }

    const activateProgressStep = (step) => {
      const stepOrder = ["prepare", "execute", "finish"]
      const activeIndex = stepOrder.indexOf(step)
      progressSteps.forEach((item) => {
        const itemIndex = stepOrder.indexOf(item.dataset.adminOperationStep)
        item.classList.toggle("admin-operation-progress-step-active", itemIndex === activeIndex)
        item.classList.toggle("admin-operation-progress-step-complete", itemIndex < activeIndex)
      })
    }

    const estimatedExternalFetchProgress = () => {
      if (!executeStartedAt) return 8

      const elapsedSeconds = Math.max(0, Math.floor((Date.now() - executeStartedAt) / 1000))
      const progressRatio = Math.min(elapsedSeconds / estimatedSeconds, 1)
      const estimated = 8 + (84 * Math.pow(progressRatio, 0.72))
      return Math.min(92, Math.max(8, Math.floor(estimated)))
    }

    const updateProgress = (value, status, label) => {
      const normalizedValue = Math.max(0, Math.min(100, value))
      if (progressLabel && label) progressLabel.textContent = label
      if (progressPercent) progressPercent.textContent = `${normalizedValue}%`
      if (progressStatus) progressStatus.textContent = status
      if (progressbar) {
        progressbar.setAttribute("aria-valuenow", normalizedValue.toString())
        progressbar.setAttribute("aria-valuetext", `${status} ${normalizedValue}%`)
      }
      if (progressBar) progressBar.style.width = `${normalizedValue}%`
    }

    const resetProgress = () => {
      if (elapsedTimer) window.clearInterval(elapsedTimer)
      if (pollTimer) window.clearInterval(pollTimer)
      if (finishTimer) window.clearTimeout(finishTimer)

      elapsedTimer = undefined
      pollTimer = undefined
      finishTimer = undefined
      executeStartedAt = undefined
      progressPhase = "waiting"
      lastServerPercentage = 0
      hasServerProgress = false
      lastProgressStatus = "外部サイト取得中"
      lastProgressLabel = "外部サイトから取得・保存しています..."
      delete form.dataset.confirmed

      if (submitButton) submitButton.disabled = false
      if (modalCancelButton) modalCancelButton.disabled = false
      if (progress) progress.hidden = true
      if (progressElapsed) progressElapsed.textContent = "00:00"
      progressBar?.classList.remove("admin-operation-progress-bar-active")
      activateProgressStep("prepare")
      updateProgress(0, "待機中", "処理を開始しています...")
      updateAdminOperationSubmitStates()
    }

    const finishProgress = (payload = {}) => {
      if (progress?.hidden || progressPhase === "finished") return

      progressPhase = "finished"
      activateProgressStep("finish")
      const completedLabel = payload.detail || payload.label || (inlineConfirmation ? "処理が完了しました。ダイアログを閉じます..." : "処理が完了しました。画面を切り替えています...")
      updateProgress(100, "完了", completedLabel)
      if (elapsedTimer) window.clearInterval(elapsedTimer)
      if (pollTimer) window.clearInterval(pollTimer)
      if (inlineConfirmation && operationModal?.open) {
        finishTimer = window.setTimeout(() => {
          operationModal.close()
          resetProgress()
        }, 1200)
      }
    }

    const applyServerProgress = (payload) => {
      if (!payload || progressPhase === "finished") return

      const percentage = Number.parseInt(payload.percentage || "0", 10)
      const status = payload.status || "外部サイト取得中"
      const label = payload.label || "外部サイトから取得・保存しています..."
      lastProgressStatus = status
      lastProgressLabel = label

      if (Number.isFinite(percentage)) {
        hasServerProgress = payload.state !== "pending" || percentage > 0
        lastServerPercentage = Math.max(lastServerPercentage, percentage)
        updateProgress(lastServerPercentage, status, label)
      } else {
        updateProgress(lastServerPercentage, status, label)
      }

      if (payload.state === "running") activateProgressStep("execute")
      if (payload.state === "completed") finishProgress(payload)
      if (payload.state === "failed") {
        progressPhase = "failed"
        updateProgress(lastServerPercentage, "エラー", payload.detail || label)
        if (pollTimer) window.clearInterval(pollTimer)
        if (elapsedTimer) window.clearInterval(elapsedTimer)
        progressBar?.classList.remove("admin-operation-progress-bar-active")
        if (modalCancelButton) modalCancelButton.disabled = false
        delete form.dataset.adminOperationBusy
        delete form.dataset.confirmed
        updateAdminOperationSubmitStates()
      }
    }

    const startProgressPolling = () => {
      if (!progressUrl) return

      const poll = async () => {
        try {
          const response = await fetch(progressUrl, {
            headers: {
              Accept: "application/json",
              "X-Requested-With": "XMLHttpRequest",
            },
          })
          if (!response.ok) return

          applyServerProgress(await response.json())
        } catch (error) {
          console.debug(error)
        }
      }

      poll()
      pollTimer = window.setInterval(poll, 1200)
    }

    const startProgress = () => {
      if (progress) progress.hidden = false
      form.dataset.adminOperationBusy = "true"
      if (submitButton) submitButton.disabled = true
      if (modalCancelButton) modalCancelButton.disabled = true
      progressPhase = "prepare"
      activateProgressStep("prepare")
      updateProgress(4, "確認中", "入力内容を確認しています...")

      const startedAt = Date.now()
      if (progressElapsed) progressElapsed.textContent = elapsedTime(startedAt)
      elapsedTimer = window.setInterval(() => {
        if (progressElapsed) progressElapsed.textContent = elapsedTime(startedAt)
        if (progressPhase === "execute") {
          const fallbackProgress = estimatedExternalFetchProgress()
          const nextProgress = hasServerProgress ? lastServerPercentage : fallbackProgress
          updateProgress(nextProgress, lastProgressStatus, lastProgressLabel)
        }
      }, 1000)

      window.setTimeout(() => {
        progressPhase = "execute"
        executeStartedAt = Date.now()
        activateProgressStep("execute")
        progressBar?.classList.add("admin-operation-progress-bar-active")
        updateProgress(8, "外部サイト取得中", "外部サイトから取得・保存しています...")
      }, 250)

      startProgressPolling()
      window.addEventListener("pagehide", finishProgress, { once: true })
    }

    const failProgress = (message) => {
      progressPhase = "failed"
      updateProgress(lastServerPercentage, "エラー", message || "処理の開始に失敗しました")
      if (pollTimer) window.clearInterval(pollTimer)
      if (elapsedTimer) window.clearInterval(elapsedTimer)
      progressBar?.classList.remove("admin-operation-progress-bar-active")
      if (modalCancelButton) modalCancelButton.disabled = false
      delete form.dataset.adminOperationBusy
      delete form.dataset.confirmed
      updateAdminOperationSubmitStates()
    }

    const submitAsyncOperation = async () => {
      syncSelectedIds()
      startProgress()

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

        applyServerProgress(payload.progress)
      } catch (error) {
        console.error(error)
        failProgress(error.message)
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
        startProgress()
        return
      }

      if (inlineConfirmation) {
        syncSelectedIds()
        if (asyncOperation) {
          event.preventDefault()
          submitAsyncOperation()
          return
        }
        startProgress()
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
      if (progressPhase !== "waiting") resetProgress()
    })

    operationPanel?.addEventListener("admin-operation-panel-open", () => {
      resetProgress()
    })

    updateAdminOperationSubmitStates()
  })
}


export const setupAdminResourceOperations = () => {
  setupAdminResourceSelection({ afterUpdate: updateAdminOperationSubmitStates })
  setupAdminOperationModal({ updateSelectionState: updateAdminResourceSelectionState })
  setupAdminOperationForms()
}
