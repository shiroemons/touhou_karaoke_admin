const DEFAULT_PROGRESS_STATUS = "外部サイト取得中"
const DEFAULT_PROGRESS_LABEL = "外部サイトから取得・保存しています..."
const POLL_INTERVAL_MS = 1200
const MAX_POLL_RETRIES = 3
const MAX_POLL_DELAY_MS = 10000
const OPERATION_PROGRESS_TIMEOUT_MS = 15000

const createOperationProgressTimeout = (controller, timeoutMs = OPERATION_PROGRESS_TIMEOUT_MS) => {
  const setTimeoutFunction = globalThis.setTimeout
  const clearTimeoutFunction = globalThis.clearTimeout
  if (typeof setTimeoutFunction !== "function" || typeof clearTimeoutFunction !== "function") return undefined

  let timedOut = false
  const timeoutId = setTimeoutFunction(() => {
    timedOut = true
    controller.abort()
  }, timeoutMs)

  return {
    clear: () => clearTimeoutFunction(timeoutId),
    timedOut: () => timedOut,
  }
}

const normalizeProgressValue = (value) => {
  const numericValue = Number(value)
  if (!Number.isFinite(numericValue)) return 0

  return Math.max(0, Math.min(100, numericValue))
}

const elapsedTime = (startedAt) => {
  const elapsedSeconds = Math.max(0, Math.floor((Date.now() - startedAt) / 1000))
  const minutes = Math.floor(elapsedSeconds / 60).toString().padStart(2, "0")
  const seconds = (elapsedSeconds % 60).toString().padStart(2, "0")
  return `${minutes}:${seconds}`
}

export class AdminOperationProgress {
  constructor({
    form,
    operationModal,
    progress,
    progressAnnouncement,
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
    updateSubmitStates,
  }) {
    this.form = form
    this.operationModal = operationModal
    this.progress = progress
    this.progressAnnouncement = progressAnnouncement
    this.progressLabel = progressLabel
    this.progressPercent = progressPercent
    this.progressStatus = progressStatus
    this.progressElapsed = progressElapsed
    this.progressbar = progressbar
    this.progressBar = progressBar
    this.progressSteps = progressSteps
    this.modalCancelButton = modalCancelButton
    this.submitButton = submitButton
    this.inlineConfirmation = inlineConfirmation
    this.progressUrl = progressUrl
    this.estimatedSeconds = estimatedSeconds
    this.updateSubmitStates = updateSubmitStates
    this.pollSequence = 0
    this.pollController = undefined
    this.operationSequence = 0
    this.operationController = undefined
    this.resetState()
  }

  reset() {
    this.clearTimers()
    this.resetState()
    delete this.form.dataset.confirmed

    this.setBusy(false)
    if (this.submitButton) this.submitButton.disabled = false
    if (this.modalCancelButton) this.modalCancelButton.disabled = false
    if (this.progress) this.progress.hidden = true
    if (this.progressElapsed) this.progressElapsed.textContent = "00:00"
    this.progressBar?.classList.remove("admin-operation-progress-bar-active")
    this.activateStep("prepare")
    this.update(0, "待機中", "処理を開始しています...")
    this.updateSubmitStates()
  }

  finish(payload = {}) {
    if (this.progress?.hidden || this.phase === "finished") return

    this.phase = "finished"
    this.clearTimers()
    this.setBusy(false)
    this.activateStep("finish")
    const completedLabel = payload.detail || payload.label || (this.inlineConfirmation ? "処理が完了しました。ダイアログを閉じます..." : "処理が完了しました。画面を切り替えています...")
    this.update(100, "完了", completedLabel)
    if (this.inlineConfirmation && this.operationModal?.open) {
      this.finishTimer = window.setTimeout(() => {
        this.operationModal.close()
        this.reset()
      }, 1200)
    }
  }

  applyServerProgress(payload) {
    if (!payload || this.phase === "finished") return

    const percentage = Number.parseInt(payload.percentage || "0", 10)
    const status = payload.status || DEFAULT_PROGRESS_STATUS
    const label = payload.label || DEFAULT_PROGRESS_LABEL
    this.lastStatus = status
    this.lastLabel = label

    if (Number.isFinite(percentage)) {
      const normalizedPercentage = normalizeProgressValue(percentage)
      this.hasServerProgress = payload.state !== "pending" || normalizedPercentage > 0
      this.lastServerPercentage = Math.max(this.lastServerPercentage, normalizedPercentage)
      this.update(this.lastServerPercentage, status, label)
    } else {
      this.update(this.lastServerPercentage, status, label)
    }

    if (payload.state === "running") this.activateStep("execute")
    if (payload.state === "completed") this.finish(payload)
    if (payload.state === "failed") this.fail(payload.detail || label)
  }

  start() {
    this.clearTimers()
    this.resetState()
    const operationSequence = ++this.operationSequence
    this.operationController = typeof AbortController === "function" ? new AbortController() : undefined
    if (this.progress) this.progress.hidden = false
    this.setBusy(true)
    this.form.dataset.adminOperationBusy = "true"
    if (this.submitButton) this.submitButton.disabled = true
    if (this.modalCancelButton) this.modalCancelButton.disabled = true
    this.phase = "prepare"
    this.activateStep("prepare")
    this.update(4, "確認中", "入力内容を確認しています...")

    const startedAt = Date.now()
    if (this.progressElapsed) this.progressElapsed.textContent = elapsedTime(startedAt)
    this.elapsedTimer = window.setInterval(() => {
      if (this.progressElapsed) this.progressElapsed.textContent = elapsedTime(startedAt)
      if (this.phase === "execute") {
        const fallbackProgress = this.estimatedExternalFetchProgress()
        const nextProgress = this.hasServerProgress ? this.lastServerPercentage : fallbackProgress
        this.update(nextProgress, this.lastStatus, this.lastLabel)
      }
    }, 1000)

    this.executeTimer = window.setTimeout(() => {
      this.executeTimer = undefined
      if (this.phase !== "prepare") return

      this.phase = "execute"
      this.executeStartedAt = Date.now()
      this.activateStep("execute")
      this.progressBar?.classList.add("admin-operation-progress-bar-active")
      this.update(8, DEFAULT_PROGRESS_STATUS, DEFAULT_PROGRESS_LABEL)
    }, 250)

    this.startPolling()
    this.pagehideHandler = () => this.finish()
    window.addEventListener("pagehide", this.pagehideHandler, { once: true })

    return {
      sequence: operationSequence,
      signal: this.operationController?.signal,
    }
  }

  isCurrentOperation(operation) {
    return operation?.sequence === this.operationSequence && !["waiting", "finished", "failed"].includes(this.phase)
  }

  fail(message) {
    this.phase = "failed"
    this.setBusy(false)
    this.update(this.lastServerPercentage, "エラー", message || "処理の開始に失敗しました")
    this.clearTimers()
    this.progressBar?.classList.remove("admin-operation-progress-bar-active")
    if (this.modalCancelButton) this.modalCancelButton.disabled = false
    delete this.form.dataset.adminOperationBusy
    delete this.form.dataset.confirmed
    this.updateSubmitStates()
  }

  resetState() {
    this.elapsedTimer = undefined
    this.pollTimer = undefined
    this.finishTimer = undefined
    this.executeTimer = undefined
    this.executeStartedAt = undefined
    this.pollFailureCount = 0
    this.pollInFlight = false
    this.phase = "waiting"
    this.lastServerPercentage = 0
    this.hasServerProgress = false
    this.lastStatus = DEFAULT_PROGRESS_STATUS
    this.lastLabel = DEFAULT_PROGRESS_LABEL
  }

  clearTimers() {
    this.pollSequence += 1
    this.pollInFlight = false
    if (this.pollController) {
      this.pollController.abort()
      this.pollController = undefined
    }
    if (this.elapsedTimer !== undefined) {
      window.clearInterval(this.elapsedTimer)
      this.elapsedTimer = undefined
    }
    if (this.pollTimer !== undefined) {
      window.clearTimeout(this.pollTimer)
      this.pollTimer = undefined
    }
    if (this.finishTimer !== undefined) {
      window.clearTimeout(this.finishTimer)
      this.finishTimer = undefined
    }
    if (this.executeTimer !== undefined) {
      window.clearTimeout(this.executeTimer)
      this.executeTimer = undefined
    }
    if (this.operationController) {
      this.operationController.abort()
      this.operationController = undefined
    }
    this.removePagehideHandler()
  }

  removePagehideHandler() {
    if (!this.pagehideHandler) return

    window.removeEventListener("pagehide", this.pagehideHandler)
    this.pagehideHandler = undefined
  }

  setBusy(busy) {
    this.progress?.setAttribute("aria-busy", busy.toString())
  }

  activateStep(step) {
    const stepOrder = ["prepare", "execute", "finish"]
    const activeIndex = stepOrder.indexOf(step)
    this.progressSteps.forEach((item) => {
      const itemIndex = stepOrder.indexOf(item.dataset.adminOperationStep)
      item.classList.toggle("admin-operation-progress-step-active", itemIndex === activeIndex)
      item.classList.toggle("admin-operation-progress-step-complete", itemIndex < activeIndex)
    })
  }

  estimatedExternalFetchProgress() {
    if (!this.executeStartedAt) return 8

    const elapsedSeconds = Math.max(0, Math.floor((Date.now() - this.executeStartedAt) / 1000))
    const progressRatio = Math.min(elapsedSeconds / this.estimatedSeconds, 1)
    const estimated = 8 + (84 * Math.pow(progressRatio, 0.72))
    return Math.min(92, Math.max(8, Math.floor(estimated)))
  }

  update(value, status, label) {
    const normalizedValue = normalizeProgressValue(value)
    if (this.progressLabel && label) this.progressLabel.textContent = label
    if (this.progressPercent) this.progressPercent.textContent = `${normalizedValue}%`
    if (this.progressStatus) this.progressStatus.textContent = status
    if (this.progressAnnouncement) {
      const announcement = [status, label].filter(Boolean).join("。")
      if (this.progressAnnouncement.textContent !== announcement) this.progressAnnouncement.textContent = announcement
    }
    if (this.progressbar) {
      this.progressbar.setAttribute("aria-valuenow", normalizedValue.toString())
      this.progressbar.setAttribute("aria-valuetext", `${status} ${normalizedValue}%`)
    }
    if (this.progressBar) this.progressBar.style.width = `${normalizedValue}%`
  }

  startPolling() {
    if (!this.progressUrl) return

    this.pollController?.abort()
    const pollSequence = ++this.pollSequence
    const poll = async () => {
      if (this.phase === "finished" || this.phase === "failed" || this.pollInFlight) return

      this.pollInFlight = true
      const controller = typeof AbortController === "function" ? new AbortController() : undefined
      this.pollController = controller
      const requestTimeout = controller ? createOperationProgressTimeout(controller) : undefined
      try {
        const response = await fetch(this.progressUrl, {
          headers: {
            Accept: "application/json",
            "X-Requested-With": "XMLHttpRequest",
          },
          signal: controller?.signal,
        })
        if (this.pollSequence !== pollSequence) return
        if (!response.ok) {
          const error = new Error(`処理状態の取得に失敗しました（HTTP ${response.status}）。`)
          error.status = response.status
          throw error
        }

        const payload = await response.json()
        if (requestTimeout?.timedOut()) throw new Error("処理状態の取得がタイムアウトしました。")
        if (this.pollSequence !== pollSequence) return
        this.pollFailureCount = 0
        this.applyServerProgress(payload)
      } catch (error) {
        if ((error?.name === "AbortError" && !requestTimeout?.timedOut()) || this.pollSequence !== pollSequence) return

        if (error?.status === 404) {
          this.fail("処理状態が見つかりません。再実行するか、画面を再読み込みしてください。")
          return
        }

        this.pollFailureCount += 1
        if (this.pollFailureCount >= MAX_POLL_RETRIES) {
          this.fail("処理状態を確認できません。再実行するか、画面を再読み込みしてください。")
          return
        }

        this.lastStatus = "再試行中"
        this.lastLabel = `進捗を確認できません。${this.pollFailureCount}/${MAX_POLL_RETRIES}回目の再試行を待っています...`
        this.update(this.lastServerPercentage, this.lastStatus, this.lastLabel)
      } finally {
        requestTimeout?.clear()
        if (this.pollController === controller) this.pollController = undefined
        if (this.pollSequence !== pollSequence) return
        this.pollInFlight = false
        if (this.phase === "finished" || this.phase === "failed") return

        const retryDelay = this.pollFailureCount > 0
          ? Math.min(MAX_POLL_DELAY_MS, POLL_INTERVAL_MS * (2 ** (this.pollFailureCount - 1)))
          : POLL_INTERVAL_MS
        this.pollTimer = window.setTimeout(poll, retryDelay)
      }
    }

    poll()
  }
}
