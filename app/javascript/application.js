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

const setupAdminOperationForms = () => {
  document.querySelectorAll("[data-admin-operation-form]").forEach((form) => {
    if (form.dataset.initialized === "true") return

    form.dataset.initialized = "true"
    const dialog = document.querySelector("[data-admin-operation-dialog]")
    const dialogMessage = dialog?.querySelector("[data-admin-operation-dialog-message]")
    const confirmButton = dialog?.querySelector("[data-admin-operation-confirm]")
    const cancelButton = dialog?.querySelector("[data-admin-operation-cancel]")
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

    const finishProgress = () => {
      if (progress?.hidden || progressPhase === "finished") return

      progressPhase = "finished"
      activateProgressStep("finish")
      updateProgress(100, "結果を反映中", "処理が完了しました。画面を切り替えています...")
      if (elapsedTimer) window.clearInterval(elapsedTimer)
      if (pollTimer) window.clearInterval(pollTimer)
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
      if (submitButton) submitButton.disabled = true
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

    const submitConfirmed = () => {
      form.dataset.confirmed = "true"
      form.requestSubmit(submitButton || undefined)
    }

    form.addEventListener("submit", (event) => {
      if (form.dataset.confirmed === "true") {
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
  })
}

document.addEventListener("DOMContentLoaded", setupAdminOperationForms)
