// Entry point for the build script in your package.json
import "@rails/ujs"
import Rails from "@rails/ujs"

Rails.start()

const setupAdminInfiniteScroll = () => {
  const sentinel = document.querySelector("[data-admin-infinite-scroll]")
  const rows = document.querySelector("#admin-resource-rows")
  if (!sentinel || !rows || sentinel.dataset.initialized === "true") return

  sentinel.dataset.initialized = "true"
  const scrollRoot = sentinel.closest(".admin-table-wrap")
  const status = sentinel.querySelector("[data-admin-infinite-scroll-status]")
  let loading = false

  const loadNextPage = async () => {
    const nextUrl = sentinel.dataset.nextUrl
    if (loading || !nextUrl) return

    loading = true
    if (status) status.textContent = "読み込み中..."

    try {
      const response = await fetch(nextUrl, {
        headers: {
          Accept: "application/json",
          "X-Requested-With": "XMLHttpRequest",
        },
      })

      if (!response.ok) throw new Error(`Request failed: ${response.status}`)

      const payload = await response.json()
      rows.insertAdjacentHTML("beforeend", payload.html)
      sentinel.dataset.nextUrl = payload.next_url || ""
      sentinel.hidden = !payload.next_url
      updateAdminResourceSelectionState()
      const visibleCount = document.querySelector("[data-admin-visible-count]")
      if (visibleCount) visibleCount.textContent = rows.querySelectorAll("tr").length.toLocaleString()
      if (status) status.textContent = payload.next_url ? "さらに読み込みます" : "すべて読み込みました"
    } catch (error) {
      console.error(error)
      if (status) status.textContent = "読み込みに失敗しました"
    } finally {
      loading = false
    }
  }

  const observer = new IntersectionObserver((entries) => {
    if (entries.some((entry) => entry.isIntersecting)) loadNextPage()
  }, { root: scrollRoot, rootMargin: "240px" })

  observer.observe(sentinel)
}

document.addEventListener("DOMContentLoaded", setupAdminInfiniteScroll)

const adminContentUrl = (url) => {
  const contentUrl = new URL(url, window.location.origin)
  contentUrl.searchParams.set("partial", "content")
  return contentUrl
}

const browserUrl = (url) => {
  const nextUrl = new URL(url, window.location.origin)
  nextUrl.searchParams.delete("partial")
  return nextUrl
}

const replaceAdminResourceContent = async (url, { pushState = true } = {}) => {
  const response = await fetch(adminContentUrl(url), {
    headers: {
      Accept: "application/json",
      "X-Requested-With": "XMLHttpRequest",
    },
  })

  if (!response.ok) throw new Error(`Request failed: ${response.status}`)

  const payload = await response.json()
  const currentContent = document.querySelector("[data-admin-resource-content]")
  if (!currentContent) return

  currentContent.outerHTML = payload.html
  if (pushState) window.history.pushState({}, "", browserUrl(url))
  setupAdminFilterForms()
  setupAdminInfiniteScroll()
  setupAdminResourceSelection()
  setupAdminOperationModal()
  setupAdminOperationForms()
}

const isAsyncAdminLink = (link) => {
  if (!link) return false
  if (!link.matches(".admin-sort-link, .admin-view-mode-button, .admin-pagination a, .admin-query-panel a")) return false

  const url = new URL(link.href, window.location.origin)
  return url.origin === window.location.origin && url.pathname.startsWith("/admin/")
}

const setupAdminAsyncIndex = () => {
  document.addEventListener("click", (event) => {
    const link = event.target.closest("a")
    if (!isAsyncAdminLink(link)) return

    event.preventDefault()
    replaceAdminResourceContent(link.href).catch((error) => {
      console.error(error)
      window.location.href = link.href
    })
  })

  document.addEventListener("submit", (event) => {
    const form = event.target.closest("form[data-admin-filter-form]")
    if (!form || form.method.toLowerCase() !== "get") return

    event.preventDefault()
    const url = new URL(form.action, window.location.origin)
    new FormData(form).forEach((value, key) => {
      if (value.toString().length > 0) url.searchParams.append(key, value)
    })

    replaceAdminResourceContent(url).catch((error) => {
      console.error(error)
      form.submit()
    })
  })

  window.addEventListener("popstate", () => {
    replaceAdminResourceContent(window.location.href, { pushState: false }).catch((error) => {
      console.error(error)
      window.location.reload()
    })
  })
}

document.addEventListener("DOMContentLoaded", setupAdminAsyncIndex)

const setupAdminFilterForms = () => {
  document.querySelectorAll("[data-admin-filter-form]").forEach((form) => {
    if (form.dataset.initialized === "true") return

    form.dataset.initialized = "true"
    form.querySelectorAll("[data-admin-auto-submit]").forEach((input) => {
      input.addEventListener("change", () => {
        form.requestSubmit()
      })
    })
  })
}

document.addEventListener("DOMContentLoaded", setupAdminFilterForms)

const selectedAdminResourceIds = () =>
  Array.from(document.querySelectorAll("[data-admin-resource-select]:checked")).map((input) => input.value)

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

const updateAdminResourceSelectionState = () => {
  const rowCheckboxes = Array.from(document.querySelectorAll("[data-admin-resource-select]"))
  const selectedCount = rowCheckboxes.filter((input) => input.checked).length

  document.querySelectorAll("[data-admin-resource-select-all]").forEach((input) => {
    input.checked = rowCheckboxes.length > 0 && selectedCount === rowCheckboxes.length
    input.indeterminate = selectedCount > 0 && selectedCount < rowCheckboxes.length
  })

  document.querySelectorAll("[data-admin-operation-selection-count]").forEach((item) => {
    item.textContent = selectedCount.toLocaleString()
  })
  updateAdminOperationSubmitStates()
}

const setupAdminResourceSelection = () => {
  const content = document.querySelector("[data-admin-resource-content]")
  if (!content || content.dataset.selectionInitialized === "true") return

  content.dataset.selectionInitialized = "true"
  content.addEventListener("change", (event) => {
    const selectAll = event.target.closest("[data-admin-resource-select-all]")
    if (selectAll) {
      document.querySelectorAll("[data-admin-resource-select]").forEach((input) => {
        input.checked = selectAll.checked
      })
      updateAdminResourceSelectionState()
      return
    }

    if (event.target.closest("[data-admin-resource-select]")) updateAdminResourceSelectionState()
  })

  updateAdminResourceSelectionState()
}

document.addEventListener("DOMContentLoaded", setupAdminResourceSelection)

const setupAdminOperationModal = () => {
  const modal = document.querySelector("[data-admin-operation-modal]")
  if (!modal || modal.dataset.initialized === "true") return

  modal.dataset.initialized = "true"
  const title = modal.querySelector("[data-admin-operation-modal-title]")
  const panels = Array.from(modal.querySelectorAll("[data-admin-operation-panel]"))
  const closeButton = modal.querySelector("[data-admin-operation-modal-close]")

  const showPanel = (operationKey, label) => {
    let activePanel
    panels.forEach((panel) => {
      const active = panel.dataset.adminOperationPanel === operationKey
      panel.hidden = !active
      if (active) activePanel = panel
    })
    if (title) title.textContent = label
    updateAdminResourceSelectionState()
    activePanel?.dispatchEvent(new Event("admin-operation-panel-open"))
  }

  document.querySelectorAll("[data-admin-operation-trigger]").forEach((trigger) => {
    if (trigger.dataset.modalInitialized === "true") return

    trigger.dataset.modalInitialized = "true"
    trigger.addEventListener("click", (event) => {
      const operationKey = trigger.dataset.adminOperationKey
      const panel = panels.find((item) => item.dataset.adminOperationPanel === operationKey)
      if (!panel || !modal.showModal) return

      event.preventDefault()
      trigger.closest("details")?.removeAttribute("open")
      showPanel(operationKey, trigger.textContent.trim())
      modal.showModal()
    })
  })

  closeButton?.addEventListener("click", () => modal.close())
}

document.addEventListener("DOMContentLoaded", setupAdminOperationModal)

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

    const finishProgress = () => {
      if (progress?.hidden || progressPhase === "finished") return

      progressPhase = "finished"
      activateProgressStep("finish")
      updateProgress(100, "完了", inlineConfirmation ? "処理が完了しました。ダイアログを閉じます..." : "処理が完了しました。画面を切り替えています...")
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
      if (payload.state === "completed") finishProgress()
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

document.addEventListener("DOMContentLoaded", setupAdminOperationForms)
