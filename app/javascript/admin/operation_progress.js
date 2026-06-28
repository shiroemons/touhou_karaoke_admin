const DEFAULT_PROGRESS_STATUS = "外部サイト取得中"
const DEFAULT_PROGRESS_LABEL = "外部サイトから取得・保存しています..."

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
    this.resetState()
  }

  reset() {
    this.clearTimers()
    this.resetState()
    delete this.form.dataset.confirmed

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
    this.activateStep("finish")
    const completedLabel = payload.detail || payload.label || (this.inlineConfirmation ? "処理が完了しました。ダイアログを閉じます..." : "処理が完了しました。画面を切り替えています...")
    this.update(100, "完了", completedLabel)
    if (this.elapsedTimer) window.clearInterval(this.elapsedTimer)
    if (this.pollTimer) window.clearInterval(this.pollTimer)
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
      this.hasServerProgress = payload.state !== "pending" || percentage > 0
      this.lastServerPercentage = Math.max(this.lastServerPercentage, percentage)
      this.update(this.lastServerPercentage, status, label)
    } else {
      this.update(this.lastServerPercentage, status, label)
    }

    if (payload.state === "running") this.activateStep("execute")
    if (payload.state === "completed") this.finish(payload)
    if (payload.state === "failed") this.fail(payload.detail || label)
  }

  start() {
    if (this.progress) this.progress.hidden = false
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

    window.setTimeout(() => {
      this.phase = "execute"
      this.executeStartedAt = Date.now()
      this.activateStep("execute")
      this.progressBar?.classList.add("admin-operation-progress-bar-active")
      this.update(8, DEFAULT_PROGRESS_STATUS, DEFAULT_PROGRESS_LABEL)
    }, 250)

    this.startPolling()
    window.addEventListener("pagehide", () => this.finish(), { once: true })
  }

  fail(message) {
    this.phase = "failed"
    this.update(this.lastServerPercentage, "エラー", message || "処理の開始に失敗しました")
    if (this.pollTimer) window.clearInterval(this.pollTimer)
    if (this.elapsedTimer) window.clearInterval(this.elapsedTimer)
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
    this.executeStartedAt = undefined
    this.phase = "waiting"
    this.lastServerPercentage = 0
    this.hasServerProgress = false
    this.lastStatus = DEFAULT_PROGRESS_STATUS
    this.lastLabel = DEFAULT_PROGRESS_LABEL
  }

  clearTimers() {
    if (this.elapsedTimer) window.clearInterval(this.elapsedTimer)
    if (this.pollTimer) window.clearInterval(this.pollTimer)
    if (this.finishTimer) window.clearTimeout(this.finishTimer)
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
    const normalizedValue = Math.max(0, Math.min(100, value))
    if (this.progressLabel && label) this.progressLabel.textContent = label
    if (this.progressPercent) this.progressPercent.textContent = `${normalizedValue}%`
    if (this.progressStatus) this.progressStatus.textContent = status
    if (this.progressbar) {
      this.progressbar.setAttribute("aria-valuenow", normalizedValue.toString())
      this.progressbar.setAttribute("aria-valuetext", `${status} ${normalizedValue}%`)
    }
    if (this.progressBar) this.progressBar.style.width = `${normalizedValue}%`
  }

  startPolling() {
    if (!this.progressUrl) return

    const poll = async () => {
      try {
        const response = await fetch(this.progressUrl, {
          headers: {
            Accept: "application/json",
            "X-Requested-With": "XMLHttpRequest",
          },
        })
        if (!response.ok) return

        this.applyServerProgress(await response.json())
      } catch (error) {
        console.debug(error)
      }
    }

    poll()
    this.pollTimer = window.setInterval(poll, 1200)
  }
}
