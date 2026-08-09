const POLL_INTERVAL_MS = 1500
const MAX_POLL_RETRIES = 3
const MAX_POLL_DELAY_MS = 10000
const WORKFLOW_STEP_STATUSES = new Set(["pending", "running", "completed", "failed", "manual"])

const normalizedCount = (value) => {
  const parsed = Number(value)
  return Number.isFinite(parsed) ? Math.max(0, Math.trunc(parsed)) : 0
}

const normalizedPercentage = (value) => Math.min(100, normalizedCount(value))

const normalizedStepStatus = (status) => WORKFLOW_STEP_STATUSES.has(status) ? status : "unknown"

export const setupAdminWorkflowRunner = ({ showFlash } = {}) => {
  document.querySelectorAll("[data-admin-workflow-runner]").forEach((runner) => {
    if (runner.dataset.initialized === "true") return
    if (!runner.dataset.adminWorkflowRunId || !runner.dataset.adminWorkflowProgressUrl) return

    runner.dataset.initialized = "true"
    const stepItems = Array.from(runner.querySelectorAll("[data-admin-workflow-step]"))
    const statusPanel = document.querySelector("[data-admin-workflow-status]")
    const statusLabel = statusPanel?.querySelector("[data-admin-workflow-status-label]")
    const statusState = statusPanel?.querySelector("[data-admin-workflow-status-state]")
    const statusPercent = statusPanel?.querySelector("[data-admin-workflow-status-percent]")
    const statusCurrent = statusPanel?.querySelector("[data-admin-workflow-status-current]")
    const statusCount = statusPanel?.querySelector("[data-admin-workflow-status-count]")
    const currentStepLabel = runner.querySelector("[data-admin-workflow-current-step]")
    const resultsPanel = document.querySelector("[data-admin-workflow-results]")
    const resultsList = resultsPanel?.querySelector("[data-admin-workflow-result-list]")
    let completionNotified = runner.dataset.adminWorkflowState === "completed"
    let pollFailureCount = 0
    let pollInFlight = false
    let pollTimer
    let pollingStopped = false
    let pollController
    let pagehideHandler

    const removePagehideHandler = () => {
      if (!pagehideHandler) return

      window.removeEventListener?.("pagehide", pagehideHandler)
      pagehideHandler = undefined
    }

    const runnerIsMounted = () => runner.isConnected !== false

    const applyStatus = (payload) => {
      const currentStep = payload.workflow?.current_step
      const currentText = currentStep?.label || (payload.state === "completed" ? "完了" : "確認中")

      if (statusPanel) {
        if (statusLabel) statusLabel.textContent = payload.label || "実行状況を確認しています"
        if (statusState) statusState.textContent = payload.status || payload.state || "確認中"
        if (statusPercent) statusPercent.textContent = `${normalizedPercentage(payload.percentage)}%`
        if (statusCurrent) statusCurrent.textContent = currentText
      }
      if (currentStepLabel) currentStepLabel.textContent = `現在: ${currentText}`
      if (statusPanel && statusCount) {
        const workflow = payload.workflow || {}
        const totalSteps = normalizedCount(workflow.total_steps)
        const completedSteps = Math.min(totalSteps, normalizedCount(workflow.completed_steps))
        statusCount.textContent = `${completedSteps} / ${totalSteps}`
      }
    }

    const applyStep = (step) => {
      const item = stepItems.find((candidate) => candidate.dataset.adminWorkflowStep === step.key)
      if (!item) return

      const status = normalizedStepStatus(step.status)
      item.dataset.adminWorkflowStatus = status
      const progress = item.querySelector("[data-admin-workflow-step-progress]")
      const childProgress = step.progress || {}
      const labels = {
        pending: "順番待ち",
        running: childProgress.label || "実行中",
        completed: childProgress.detail || "完了",
        failed: step.error || childProgress.detail || "失敗",
        manual: "個別実行のみ",
        unknown: "状態不明",
      }
      if (progress) {
        progress.textContent = labels[status]
        if (status === "running") progress.textContent += ` ${normalizedPercentage(childProgress.percentage)}%`
      }
    }

    const attemptDetailText = (step) => {
      const attempts = Array.isArray(step.attempts) && step.attempts.length > 0 ? step.attempts : [{ attempt: step.attempt, detail: step.detail }]
      return attempts
        .filter((attempt) => attempt?.detail)
        .map((attempt) => {
          const attemptNumber = Number.parseInt(attempt.attempt || "1", 10)
          return `${attemptNumber > 1 ? `${attemptNumber}周目: ` : ""}${attempt.detail}`
        })
        .join(" / ")
    }

    const applyResults = (payload) => {
      if (!resultsPanel || !resultsList) return

      const resultSteps = payload.workflow?.result_steps || []
      resultsPanel.hidden = resultSteps.length === 0
      resultsList.replaceChildren()
      resultSteps.forEach((step) => {
        const item = document.createElement("li")
        item.className = "admin-workflow-result-item"
        item.dataset.adminWorkflowResultStep = step.key

        const title = document.createElement("strong")
        const attempt = Number.parseInt(step.attempt || "1", 10)
        title.textContent = `${step.label}${attempt > 1 ? `（${attempt}周実行）` : ""}`

        const detail = document.createElement("span")
        detail.textContent = attemptDetailText(step)

        item.append(title, detail)
        resultsList.appendChild(item)
      })
    }

    const applyConnectionState = ({ state, status, label, current }) => {
      runner.dataset.adminWorkflowState = state
      if (statusLabel) statusLabel.textContent = label
      if (statusState) statusState.textContent = status
      if (statusCurrent) statusCurrent.textContent = current
      if (currentStepLabel) currentStepLabel.textContent = `現在: ${current}`
    }

    const stopPolling = () => {
      if (pollingStopped) return

      pollingStopped = true
      if (pollTimer !== undefined) {
        window.clearTimeout(pollTimer)
        pollTimer = undefined
      }
      if (pollController) {
        pollController.abort()
        pollController = undefined
      }
      removePagehideHandler()
    }

    const poll = async () => {
      if (pollingStopped || pollInFlight) return
      if (!runnerIsMounted()) {
        stopPolling()
        return
      }

      pollInFlight = true
      const controller = typeof AbortController === "function" ? new AbortController() : undefined
      pollController = controller
      try {
        const response = await fetch(runner.dataset.adminWorkflowProgressUrl, {
          headers: {
            Accept: "application/json",
            "X-Requested-With": "XMLHttpRequest",
          },
          signal: controller?.signal,
        })
        if (!response.ok) {
          const error = new Error(`運用フロー進捗の取得に失敗しました（HTTP ${response.status}）。`)
          error.status = response.status
          throw error
        }

        const payload = await response.json()
        if (pollingStopped || !runnerIsMounted()) {
          stopPolling()
          return
        }
        if (!payload || typeof payload !== "object" || Array.isArray(payload)) {
          throw new Error("運用フロー進捗の形式が不正です。")
        }

        pollFailureCount = 0
        applyStatus(payload)
        payload.workflow?.steps?.forEach(applyStep)
        applyResults(payload)
        runner.dataset.adminWorkflowState = payload.state
        if (payload.state === "completed" && !completionNotified) {
          completionNotified = true
          showFlash?.(payload.label || `${payload.workflow?.workflow_label || "運用フロー"}が完了しました。`)
        }
        if (payload.state === "completed" || payload.state === "failed") stopPolling()
      } catch (error) {
        if (error?.name === "AbortError" || pollingStopped || !runnerIsMounted()) {
          stopPolling()
          return
        }

        if (error.status === 404) {
          applyConnectionState({
            state: "unknown",
            status: "状態不明",
            label: "実行状況が見つかりません。画面を再読み込みしてください。",
            current: "確認できません",
          })
          stopPolling()
          return
        }

        pollFailureCount += 1
        if (pollFailureCount >= MAX_POLL_RETRIES) {
          applyConnectionState({
            state: "failed",
            status: "エラー",
            label: "実行状況を確認できません。画面を再読み込みしてください。",
            current: "確認できません",
          })
          stopPolling()
          return
        }

        applyConnectionState({
          state: "retrying",
          status: "再試行中",
          label: `実行状況を確認できません。${pollFailureCount}/${MAX_POLL_RETRIES}回目の再試行を待っています...`,
          current: "再接続待ち",
        })
      } finally {
        if (pollController === controller) pollController = undefined
        pollInFlight = false
        if (pollingStopped) return

        const retryDelay = pollFailureCount > 0
          ? Math.min(MAX_POLL_DELAY_MS, POLL_INTERVAL_MS * (2 ** (pollFailureCount - 1)))
          : POLL_INTERVAL_MS
        pollTimer = window.setTimeout(poll, retryDelay)
      }
    }

    pagehideHandler = () => stopPolling()
    window.addEventListener?.("pagehide", pagehideHandler, { once: true })
    poll()
  })
}
