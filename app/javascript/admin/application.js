// Entry point for the build script in your package.json
import "@rails/ujs"
import Rails from "@rails/ujs"
import { setupAdminBulkEditControls } from "./bulk_edit_controls"
import { setupAdminFlash, showAdminFlash } from "./flash"
import { setupAdminInfiniteScroll } from "./infinite_scroll"
import { setupAdminFilterForms, setupAdminNavigation } from "./navigation"
import { setupAdminResourceOperations, updateAdminResourceSelectionState } from "./resource_operations"

Rails.start()

document.addEventListener("DOMContentLoaded", setupAdminFlash)
document.addEventListener("DOMContentLoaded", () => setupAdminInfiniteScroll({ updateSelectionState: updateAdminResourceSelectionState }))
document.addEventListener("DOMContentLoaded", setupAdminBulkEditControls)
document.addEventListener("DOMContentLoaded", () => setupAdminNavigation({ setupPageBehaviors: setupAdminPageBehaviors }))

const setupAdminPageBehaviors = () => {
  setupAdminFilterForms()
  setupAdminInfiniteScroll({ updateSelectionState: updateAdminResourceSelectionState })
  setupAdminBulkEditControls()
  setupAdminResourceOperations()
  setupAdminWorkflowRunner()
}

document.addEventListener("DOMContentLoaded", setupAdminResourceOperations)

const setupAdminWorkflowRunner = () => {
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

    const applyStatus = (payload) => {
      const currentStep = payload.workflow?.current_step
      const currentText = currentStep?.label || (payload.state === "completed" ? "完了" : "確認中")

      if (statusPanel) {
        if (statusLabel) statusLabel.textContent = payload.label || "実行状況を確認しています"
        if (statusState) statusState.textContent = payload.status || payload.state || "確認中"
        if (statusPercent) statusPercent.textContent = `${Number.parseInt(payload.percentage || "0", 10)}%`
        if (statusCurrent) statusCurrent.textContent = currentText
      }
      if (currentStepLabel) currentStepLabel.textContent = `現在: ${currentText}`
      if (statusPanel && statusCount) {
        const workflow = payload.workflow || {}
        statusCount.textContent = `${Number.parseInt(workflow.completed_steps || "0", 10)} / ${Number.parseInt(workflow.total_steps || "0", 10)}`
      }
    }

    const applyStep = (step) => {
      const item = stepItems.find((candidate) => candidate.dataset.adminWorkflowStep === step.key)
      if (!item) return

      item.dataset.adminWorkflowStatus = step.status
      const progress = item.querySelector("[data-admin-workflow-step-progress]")
      const childProgress = step.progress || {}
      const labels = {
        pending: "順番待ち",
        running: childProgress.label || "実行中",
        completed: childProgress.detail || "完了",
        failed: step.error || childProgress.detail || "失敗",
        manual: "個別実行のみ",
      }
      if (progress) {
        progress.textContent = labels[step.status] || step.status
        if (step.status === "running" && Number.isFinite(Number.parseInt(childProgress.percentage || "0", 10))) {
          progress.textContent += ` ${Number.parseInt(childProgress.percentage || "0", 10)}%`
        }
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

    const poll = async () => {
      try {
        const response = await fetch(runner.dataset.adminWorkflowProgressUrl, {
          headers: {
            Accept: "application/json",
            "X-Requested-With": "XMLHttpRequest",
          },
        })
        if (!response.ok) return

        const payload = await response.json()
        applyStatus(payload)
        payload.workflow?.steps?.forEach(applyStep)
        applyResults(payload)
        runner.dataset.adminWorkflowState = payload.state
        if (payload.state === "completed" && !completionNotified) {
          completionNotified = true
          showAdminFlash(payload.label || `${payload.workflow?.workflow_label || "運用フロー"}が完了しました。`)
        }
        if (payload.state === "completed" || payload.state === "failed") return
        window.setTimeout(poll, 1500)
      } catch (error) {
        console.error(error)
        window.setTimeout(poll, 3000)
      }
    }

    poll()
  })
}

document.addEventListener("DOMContentLoaded", setupAdminWorkflowRunner)
