// Entry point for the build script in your package.json
import "@rails/ujs"
import Rails from "@rails/ujs"
import { setupAdminBulkEditControls } from "./bulk_edit_controls"
import { setupAdminFlash, showAdminFlash } from "./flash"
import { setupAdminInfiniteScroll } from "./infinite_scroll"
import { setupAdminResourceOperations, updateAdminResourceSelectionState } from "./resource_operations"

Rails.start()

document.addEventListener("DOMContentLoaded", setupAdminFlash)
document.addEventListener("DOMContentLoaded", () => setupAdminInfiniteScroll({ updateSelectionState: updateAdminResourceSelectionState }))
document.addEventListener("DOMContentLoaded", setupAdminBulkEditControls)


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

const setupAdminPageBehaviors = () => {
  setupAdminFilterForms()
  setupAdminInfiniteScroll({ updateSelectionState: updateAdminResourceSelectionState })
  setupAdminBulkEditControls()
  setupAdminResourceOperations()
  setupAdminWorkflowRunner()
}

document.addEventListener("DOMContentLoaded", setupAdminResourceOperations)

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
  setupAdminPageBehaviors()
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

}

document.addEventListener("DOMContentLoaded", setupAdminAsyncIndex)

let adminPageNavigationController

const adminPageUrl = (url) => {
  const nextUrl = new URL(url, window.location.origin)
  nextUrl.searchParams.delete("partial")
  return nextUrl
}

const isPrimaryNavigationClick = (event) =>
  event.button === 0 && !event.metaKey && !event.ctrlKey && !event.shiftKey && !event.altKey

const isAsyncAdminPageLink = (link, event) => {
  if (!link || !isPrimaryNavigationClick(event)) return false
  if (event.defaultPrevented) return false
  if (link.matches("[data-admin-operation-trigger]")) return false
  if (link.target || link.hasAttribute("download")) return false
  if (link.dataset.turbo === "false" || link.dataset.adminFullPage === "true") return false
  if (link.dataset.method && link.dataset.method.toLowerCase() !== "get") return false
  if (isAsyncAdminLink(link)) return false

  const url = adminPageUrl(link.href)
  return url.origin === window.location.origin && url.pathname.startsWith("/admin/")
}

const replaceAdminPage = (html, url, { pushState = true } = {}) => {
  const nextDocument = new DOMParser().parseFromString(html, "text/html")
  const nextContent = nextDocument.querySelector("[data-admin-page-content]")
  const currentContent = document.querySelector("[data-admin-page-content]")

  if (!nextContent || !currentContent) throw new Error("Admin page content was not found.")

  const nextSidebar = nextDocument.querySelector(".admin-sidebar")
  const currentSidebar = document.querySelector(".admin-sidebar")
  if (nextSidebar && currentSidebar) currentSidebar.outerHTML = nextSidebar.outerHTML

  currentContent.replaceWith(nextContent)
  document.title = nextDocument.title || document.title
  if (pushState) window.history.pushState({}, "", adminPageUrl(url))

  const pageContent = document.querySelector("[data-admin-page-content]")
  pageContent?.scrollTo({ top: 0, left: 0 })
  setupAdminPageBehaviors()
}

const fetchAndReplaceAdminPage = async (url, { pushState = true } = {}) => {
  if (adminPageNavigationController) adminPageNavigationController.abort()

  const controller = new AbortController()
  adminPageNavigationController = controller
  document.body.dataset.adminNavigation = "loading"
  document.querySelector("[data-admin-page-content]")?.setAttribute("aria-busy", "true")

  try {
    const response = await fetch(adminPageUrl(url), {
      credentials: "same-origin",
      headers: {
        Accept: "text/html",
        "X-Requested-With": "XMLHttpRequest",
      },
      signal: controller.signal,
    })

    if (!response.ok) throw new Error(`Request failed: ${response.status}`)

    replaceAdminPage(await response.text(), response.url, { pushState })
  } finally {
    if (adminPageNavigationController === controller) {
      delete document.body.dataset.adminNavigation
      document.querySelector("[data-admin-page-content]")?.removeAttribute("aria-busy")
      adminPageNavigationController = undefined
    }
  }
}

const setupAdminPageNavigation = () => {
  if (document.documentElement.dataset.adminPageNavigationInitialized === "true") return

  document.documentElement.dataset.adminPageNavigationInitialized = "true"
  document.addEventListener("click", (event) => {
    const link = event.target.closest("a")
    if (!isAsyncAdminPageLink(link, event)) return

    event.preventDefault()
    fetchAndReplaceAdminPage(link.href).catch((error) => {
      if (error.name === "AbortError") return

      console.error(error)
      window.location.href = link.href
    })
  })

  window.addEventListener("popstate", () => {
    fetchAndReplaceAdminPage(window.location.href, { pushState: false }).catch((error) => {
      if (error.name === "AbortError") return

      console.error(error)
      window.location.reload()
    })
  })
}

document.addEventListener("DOMContentLoaded", setupAdminPageNavigation)

const isAdminClickableRowTarget = (target) =>
  !target.closest("a, button, input, select, textarea, label, form, [data-admin-row-ignore]")

const setupAdminClickableRows = () => {
  if (document.documentElement.dataset.adminClickableRowsInitialized === "true") return

  document.documentElement.dataset.adminClickableRowsInitialized = "true"
  document.addEventListener("click", (event) => {
    if (!isPrimaryNavigationClick(event) || event.defaultPrevented) return
    if (!isAdminClickableRowTarget(event.target)) return

    const row = event.target.closest("[data-admin-row-href]")
    if (!row?.dataset.adminRowHref) return

    event.preventDefault()
    fetchAndReplaceAdminPage(row.dataset.adminRowHref).catch((error) => {
      if (error.name === "AbortError") return

      console.error(error)
      window.location.href = row.dataset.adminRowHref
    })
  })
}

document.addEventListener("DOMContentLoaded", setupAdminClickableRows)

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
